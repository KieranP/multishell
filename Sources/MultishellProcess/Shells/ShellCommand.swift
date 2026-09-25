import Foundation

/// Runs a user-supplied command line as sh, started from the user's shell so
/// their startup files set its environment; see Docs/design/hooks.md.
public enum ShellCommand {
  /// Starts a command with no pipes and no timeout, waiting only to hear how
  /// it ended: an editor shim may hold this open; see terminals.md.
  public static func launch(
    _ commandLine: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String
  ) async throws {
    let shell = ShellInvocation.userShell(at: shellPath)
    let arguments = shell.arguments + [Self.evalScriptCommand]
    // Not historyless: an editor started here keeps what its terminals inherit.
    let environment = environment.merging([Self.scriptVariable: commandLine]) { $1 }
    // Nothing to drain and nothing to fill: all three are /dev/null.
    let nullDevice = try NullDevice()
    defer { nullDevice.close() }
    let null = nullDevice.descriptor
    let status = try await DetachedLaunch.run(
      shell.executable, arguments, in: directory, environment: environment,
      input: null, output: null, error: null, closingOutputsAfterSpawn: false
    ) { _ in nullDevice.close() }
    // Names the user's line, not the constant the shell was handed.
    guard status == 0 else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: shell.arguments + [commandLine],
        status: status, message: "")
    }
  }

  /// A multi-line sh script whose first failing line ends it, inside an
  /// interactive login shell; see Docs/design/hooks.md.
  public static func runScript(
    _ script: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> String {
    let shell = ShellInvocation.userShell(at: shellPath)
    let arguments = shell.arguments + [Self.evalScriptCommand]
    let environment = ShellInvocation.historyless(environment)
      .merging([Self.scriptVariable: Self.prologue(entering: directory) + script]) { $1 }
    let output = try await ProcessRunner().capture(
      shell.executable, arguments, in: directory, environment: environment,
      timeout: timeout, stopper: stopper)
    guard output.succeeded, output.stop == nil else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: shell.arguments + [script],
        status: output.status,
        message: Self.failureMessage(
          standardOutput: output.standardOutput, standardError: output.standardError),
        stop: output.stop)
    }
    return output.standardOutput
  }

  /// What a failed script printed, stdout first. The two streams are read
  /// apart, so their order against each other is not kept.
  static func failureMessage(standardOutput: String, standardError: String) -> String {
    [standardOutput, scriptOutput(fromStderr: standardError)]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  /// Where the script travels: csh cannot take a newline inside quotes, and
  /// an interactive csh expands a `!` in them, so it is never in the command.
  static let scriptVariable = "MULTISHELL_SCRIPT"

  /// What the shell is handed: one line every listed shell reads alike, so the
  /// script is sh whichever set the environment. The variable is unset for its children.
  static let evalScriptCommand =
    "exec /bin/sh -c '_multishell_script=$\(scriptVariable); unset \(scriptVariable); "
    + "eval \"$_multishell_script\"'"

  /// Back to the script's directory, as the rc files may leave the shell
  /// anywhere; then `set -e`, then the marker its stderr is read from.
  static func prologue(entering directory: URL) -> String {
    "cd \(AnyShellQuoting.quote(directory.path)) >/dev/null || exit 1\nset -e\n"
      + "printf '%s\\n' '\(outputMarker)' >&2\n"
  }

  /// Where the script's stderr begins. Written by the script itself, so it
  /// comes after whatever the rc files printed.
  static let outputMarker = "--multishell-hook-output--"

  /// The part of a failure's stderr after the marker, or all of it where the
  /// script ended before writing one. The login shell `exec`s, so says no `logout`.
  static func scriptOutput(fromStderr text: String) -> String {
    let script = text.range(of: outputMarker).map { String(text[$0.upperBound...]) } ?? text
    return script.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
