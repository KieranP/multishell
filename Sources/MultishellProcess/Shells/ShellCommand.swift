import Foundation
import Subprocess
import System

/// Runs a user-supplied command line as sh, started from the user's shell so
/// their startup files set its environment; see Docs/design/hooks.md.
public struct ShellCommand: Sendable {
  private let runner: ProcessRunner

  public init(runner: ProcessRunner = ProcessRunner()) {
    self.runner = runner
  }

  /// Starts a command with no pipes and no timeout, waiting only to hear how
  /// it ended: an editor shim may hold this open; see terminals.md.
  public func launch(
    _ commandLine: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String
  ) async throws {
    let shell = Self.shell(named: shellPath)
    let arguments = shell.arguments + [Self.runningScriptVariable]
    // Not historyless: an editor started here keeps what its terminals inherit.
    let environment = environment.merging([Self.scriptVariable: commandLine]) { $1 }
    // Nothing to drain and nothing to fill: all three are /dev/null.
    let nullDevice = try DetachedLaunch.NullDevice()
    defer { nullDevice.close() }
    let null = nullDevice.descriptor
    let status = try await DetachedLaunch.shielded {
      let result = try await Subprocess.run(
        .path(FilePath(shell.executable.path)), arguments: Arguments(arguments),
        environment: DetachedLaunch.environment(overriding: environment),
        workingDirectory: FilePath(directory.path),
        platformOptions: DetachedLaunch.platformOptions,
        input: .fileDescriptor(null, closeAfterSpawningProcess: false),
        output: .fileDescriptor(null, closeAfterSpawningProcess: false),
        error: .fileDescriptor(null, closeAfterSpawningProcess: false)
      ) { _ in nullDevice.close() }
      return DetachedLaunch.exitCode(of: result.terminationStatus)
    }
    // Names the user's line, not the constant the shell was handed.
    guard status == 0 else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: shell.arguments + [commandLine],
        status: status, message: "")
    }
  }

  /// A multi-line sh script whose first failing line ends it, inside an
  /// interactive login shell; see Docs/design/hooks.md.
  public func runScript(
    _ script: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> String {
    let shell = Self.shell(named: shellPath)
    let arguments = shell.arguments + [Self.runningScriptVariable]
    let environment = Self.historyless(environment)
      .merging([Self.scriptVariable: Self.prologue(entering: directory) + script]) { $1 }
    let output = try await runner.capture(
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

  /// The shell is interactive, so an inherited HISTFILE is its history: bash
  /// truncates it and ksh rewrites it in its own format; see hooks.md.
  static func historyless(_ environment: [String: String]) -> [String: String] {
    environment.merging(["HISTFILE": ""]) { _, empty in empty }
  }

  /// Where the script travels: csh cannot take a newline inside quotes, and
  /// an interactive csh expands a `!` in them, so it is never in the command.
  static let scriptVariable = "MULTISHELL_SCRIPT"

  /// What the shell is handed: one line every listed shell reads alike, so the
  /// script is sh whichever set the environment. The variable is unset for its children.
  static let runningScriptVariable =
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

  /// Shells known to take `-l -i -c`. Another one (nu, xonsh, elvish) would
  /// fail on the flags, so it gets `/bin/sh` instead.
  static let interactiveLoginShells: Set<String> = [
    "sh", "bash", "zsh", "fish", "dash", "ksh", "mksh",
  ]

  /// csh and tcsh take `-l` only as their one flag, so beside `-c` they get
  /// `-i` alone, which reads `.cshrc` and `.tcshrc` but not `.login`.
  static let loginFlagRefusers: Set<String> = ["tcsh", "csh"]

  /// Runs in place of a shell that would fail on the flags, reading no
  /// startup files.
  static let fallbackShell = URL(fileURLWithPath: "/bin/sh")

  /// The user's shell, interactive and login, so a script sees a terminal's
  /// PATH: additions live in `.zprofile` for some and `.zshrc` for others.
  public static func shell(named path: String) -> ShellInvocation {
    guard FileManager.default.isExecutableFile(atPath: path) else {
      return ShellInvocation(executable: fallbackShell, arguments: ["-c"])
    }
    let name = URL(fileURLWithPath: path).lastPathComponent
    if loginFlagRefusers.contains(name) {
      return ShellInvocation(executable: URL(fileURLWithPath: path), arguments: ["-i", "-c"])
    }
    guard interactiveLoginShells.contains(name) else {
      return ShellInvocation(executable: fallbackShell, arguments: ["-c"])
    }
    return ShellInvocation(executable: URL(fileURLWithPath: path), arguments: ["-l", "-i", "-c"])
  }
}
