import Foundation

/// Runs a user-supplied command line through the platform shell: a hook is
/// written as a command, not an argv array, so it needs one to interpret it.
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
    shellPath: String? = nil
  ) async throws {
    guard let shell = Self.shell(preferring: shellPath) else { throw ShellUnavailable() }
    let arguments = shell.arguments + [commandLine]
    let process = Process()
    process.executableURL = shell.executable
    process.arguments = arguments
    process.currentDirectoryURL = directory
    // Not historyless: an editor started here keeps what its terminals inherit.
    process.environment = ProcessInfo.processInfo.environment
      .merging(environment) { _, new in new }
    // Nothing to drain and nothing to fill: a child that writes has it go
    // nowhere rather than into a buffer this side must keep reading.
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    let status = try await withCheckedThrowingContinuation { continuation in
      // Set before the start: a child that exits first would otherwise find
      // no handler, and nothing would ever resume this.
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
      do {
        try process.run()
      } catch {
        process.terminationHandler = nil
        continuation.resume(throwing: error)
      }
    }
    guard status == 0 else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: arguments, status: status,
        message: "")
    }
  }

  /// A multi-line script whose first failing line ends it, through an
  /// interactive login shell; see Docs/design/hooks.md.
  public func runScript(
    _ script: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> String {
    guard let shell = Self.shell(preferring: shellPath) else { throw ShellUnavailable() }
    // The `cd` before the marker, so a `chpwd` hook's stderr is not the hook's,
    // and before `set -e`, so a failing command inside that hook ends nothing.
    let prepared = Self.entering(
      directory,
      before: Self.stoppingAtFirstFailure(
        Self.markingOutput(script, shell: shell.executable), shell: shell.executable))
    let arguments = shell.arguments + [prepared]
    let output = try await runner.capture(
      shell.executable, arguments, in: directory, environment: Self.historyless(environment),
      timeout: timeout, stopper: stopper)
    guard output.succeeded, output.stop == nil else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: arguments,
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

  /// The rc files run first and may leave the shell anywhere, so the script
  /// goes back; quietly, as zsh's `chpwd` hooks print on every `cd`.
  static func entering(_ directory: URL, before script: String) -> String {
    "cd \(AnyShellQuoting.quote(directory.path)) >/dev/null || exit 1\n" + script
  }

  /// Shells whose `set -e` exits on the first failing command. Set inside
  /// the script, so a chatty `.zshrc` is not what stops it.
  static let errexitShells: Set<String> = ["sh", "bash", "zsh", "dash", "ksh", "mksh"]

  static func stoppingAtFirstFailure(_ script: String, shell: URL) -> String {
    guard errexitShells.contains(shell.lastPathComponent) else { return script }
    return "set -e\n" + script
  }

  /// Where the script's stderr begins. Written by the script itself, so it
  /// comes after whatever the rc files printed.
  static let outputMarker = "--multishell-hook-output--"

  /// Shells that take `>&2`. The csh family does not, and its rc files are
  /// left in the message.
  static let markingShells: Set<String> = errexitShells.union(["fish"])

  static func markingOutput(_ script: String, shell: URL) -> String {
    guard markingShells.contains(shell.lastPathComponent) else { return script }
    return "printf '%s\\n' '\(outputMarker)' >&2\n" + script
  }

  /// The part of a failure's stderr after the marker, or all of it for a
  /// shell that wrote none, without the shell's own parting word.
  static func scriptOutput(fromStderr text: String) -> String {
    let script = text.range(of: outputMarker).map { String(text[$0.upperBound...]) } ?? text
    return withoutExitNotice(script.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// What an interactive login shell prints on its way out, after the script
  /// it ran. Bash and the csh family say `logout`; zsh and fish say nothing.
  static let exitNotice = "logout"

  static func withoutExitNotice(_ text: String) -> String {
    guard text == exitNotice || text.hasSuffix("\n" + exitNotice) else { return text }
    return String(text.dropLast(exitNotice.count)).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The user's shell, interactive and login, so a hook sees a terminal's
  /// PATH: additions live in `.zprofile` for some and `.zshrc` for others.
  public static var shell: (executable: URL, arguments: [String])? {
    shell(preferring: nil)
  }

  /// A chosen shell in place of `$SHELL`, with the same fallback to
  /// `/bin/sh` for one that does not take `-l -i -c`.
  public static func shell(preferring path: String?) -> (executable: URL, arguments: [String])? {
    shell(named: path ?? ProcessInfo.processInfo.environment["SHELL"])
  }

  /// Shells known to take `-l -i -c`. Another one (nu, xonsh, elvish) would
  /// fail on the flags, so it gets `/bin/sh` instead.
  static let interactiveLoginShells: Set<String> = [
    "sh", "bash", "zsh", "fish", "dash", "ksh", "mksh",
  ]

  /// csh and tcsh take `-l` only as their one flag, so beside `-c` they get
  /// `-i` alone, which reads `.cshrc` and `.tcshrc` but not `.login`.
  static let loginFlagRefusers: Set<String> = ["tcsh", "csh"]

  static func shell(named path: String?) -> (executable: URL, arguments: [String]) {
    guard let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
      return (URL(fileURLWithPath: "/bin/sh"), ["-c"])
    }
    let name = URL(fileURLWithPath: path).lastPathComponent
    if loginFlagRefusers.contains(name) { return (URL(fileURLWithPath: path), ["-i", "-c"]) }
    guard interactiveLoginShells.contains(name) else {
      return (URL(fileURLWithPath: "/bin/sh"), ["-c"])
    }
    return (URL(fileURLWithPath: path), ["-l", "-i", "-c"])
  }
}

public struct ShellUnavailable: Error, CustomStringConvertible {
  public init() {}

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "no shell available to run hooks" }
}
