import Foundation

/// Runs a user-supplied command line through the platform shell: a hook is
/// written as a command, not an argv array, so it needs one to interpret it.
public struct ShellCommand: Sendable {
  private let runner: ProcessRunner

  public init(runner: ProcessRunner = ProcessRunner()) {
    self.runner = runner
  }

  public func run(
    _ commandLine: String,
    in directory: URL,
    environment: [String: String] = [:]
  ) async throws -> String {
    guard let shell = Self.shell else { throw ShellUnavailable() }
    return try await runner.run(
      shell.executable, shell.arguments + [commandLine], in: directory, environment: environment)
  }

  /// A multi-line script whose first failing line ends it, through an
  /// interactive login shell; see docs/design/hooks.md.
  public func runScript(
    _ script: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String? = nil,
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil
  ) async throws -> String {
    guard let shell = Self.shell(preferring: shellPath) else { throw ShellUnavailable() }
    let prepared = Self.markingOutput(
      Self.stoppingAtFirstFailure(script, shell: shell.executable), shell: shell.executable)
    let arguments = shell.arguments + [prepared]
    let output = try await runner.capture(
      shell.executable, arguments, in: directory, environment: environment, timeout: timeout,
      stopper: stopper)
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
    "sh", "bash", "zsh", "fish", "dash", "ksh", "mksh", "tcsh", "csh",
  ]

  static func shell(named path: String?) -> (executable: URL, arguments: [String]) {
    if let path, !path.isEmpty,
      interactiveLoginShells.contains(URL(fileURLWithPath: path).lastPathComponent),
      FileManager.default.isExecutableFile(atPath: path)
    {
      return (URL(fileURLWithPath: path), ["-l", "-i", "-c"])
    }
    return (URL(fileURLWithPath: "/bin/sh"), ["-c"])
  }
}

public struct ShellUnavailable: Error, CustomStringConvertible {
  public var description: String { "no shell available to run hooks" }
}
