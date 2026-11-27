import Foundation

/// Runs a user-supplied command line as sh, started from the user's shell so
/// their startup files set its environment; see Docs/design/hooks.md.
public enum ShellCommand {
  /// Where the script travels: csh cannot take a newline inside quotes, and
  /// an interactive csh expands a `!` in them, so it is never in the command.
  private static let scriptVariable = "MULTISHELL_SCRIPT"

  /// What the shell is handed: one line every listed shell reads alike, so the
  /// script is sh whichever set the environment. The variable is unset for its children.
  private static let evalScriptCommand =
    "exec /bin/sh -c '_multishell_script=$\(scriptVariable); unset \(scriptVariable); "
    + "eval \"$_multishell_script\"'"

  /// Where the script's own output begins on each stream. Written by the script
  /// itself, so it comes after whatever the rc files printed.
  static let outputStartMarker = "--multishell-hook-output--"

  /// The line a login shell is handed to run `script` as sh, and the variable
  /// carrying it, for a caller that starts the shell itself: a terminal tab.
  public static func evaluating(_ script: String) -> (line: String, environment: [String: String]) {
    (evalScriptCommand, [scriptVariable: script])
  }

  /// Runs a command line to its end with no pipes and no timeout, throwing on
  /// a failure: an editor shim may hold this open; see terminals/sessions.md.
  public static func runUncaptured(
    _ commandLine: String,
    in directory: URL,
    shellPath: String,
    environment: [String: String] = [:],
  ) async throws {
    let shell = ShellInvocation.forCommandLine(inShellAt: shellPath)
    let arguments = shell.arguments + [Self.evalScriptCommand]
    // Not historyless: an editor started here keeps what its terminals inherit.
    let environment = environment.merging([Self.scriptVariable: commandLine]) { $1 }
    let nullDevice = try NullDevice()
    defer { nullDevice.close() }
    let null = nullDevice.descriptor
    let status = try await DetachedLaunch.run(
      shell.executable,
      arguments,
      in: directory,
      environment: environment,
      input: null,
      output: null,
      error: null,
      closingOutputsAfterSpawn: false,
    ) { _ in nullDevice.close() }
    // Names the user's line, not the constant the shell was handed.
    guard status == 0 else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent,
        arguments: shell.arguments + [commandLine],
        status: status,
        message: "",
      )
    }
  }

  /// A multi-line sh script whose first failing line ends it, inside an
  /// interactive login shell, `unsetting` after its rc files; see hooks.md.
  public static func runScript(
    _ script: String,
    in directory: URL,
    shellPath: String,
    environment: [String: String] = [:],
    unsetting: [String] = [],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
  ) async throws -> String {
    let shell = ShellInvocation.forCommandLine(inShellAt: shellPath)
    let arguments = shell.arguments + [Self.evalScriptCommand]
    let environment = ShellInvocation.historyless(environment)
      .merging([
        Self.scriptVariable: Self.prologue(entering: directory, unsetting: unsetting) + script
      ]) { $1 }
    let output = try await ProcessRunner().capture(
      shell.executable,
      arguments,
      in: directory,
      environment: environment,
      timeout: timeout,
      stopper: stopper,
    )
    guard output.succeeded, output.stopReason == nil else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent,
        arguments: shell.arguments + [script],
        status: output.status,
        message: Self.failureMessage(
          standardOutput: output.standardOutput,
          standardError: output.standardError,
        ),
        stopReason: output.stopReason,
      )
    }
    return scriptOutput(output.standardOutput)
  }

  /// What a failed script printed, stdout first. The two streams are read
  /// apart, so their order against each other is not kept.
  static func failureMessage(standardOutput: String, standardError: String) -> String {
    [standardOutput, standardError].map { stream in
      scriptOutput(stream).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
  }

  /// Back to the script's directory, as the rc files may leave the shell
  /// anywhere; then the unsets, `set -e`, and the marker each stream is read from.
  private static func prologue(entering directory: URL, unsetting: [String]) -> String {
    let unsets = unsetting.map { "unset \(AnyShellQuoting.quote($0))\n" }.joined()
    return "cd \(AnyShellQuoting.quote(directory.path)) >/dev/null || exit 1\n" + unsets
      + "set -e\nprintf '%s\\n' '\(outputStartMarker)'\n"
      + "printf '%s\\n' '\(outputStartMarker)' >&2\n"
  }

  /// The part of a stream after the marker's line, or all of it where the
  /// script ended before writing one. The login shell `exec`s, so says no `logout`.
  static func scriptOutput(_ text: String) -> String {
    guard let marker = text.range(of: outputStartMarker + "\n") else { return text }
    return String(text[marker.upperBound...])
  }
}
