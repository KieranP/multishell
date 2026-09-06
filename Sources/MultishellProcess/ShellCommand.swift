import Foundation

/// Runs a user-supplied command line through the platform shell.
///
/// Hooks are written by the user as a command, not as an argv array, so they
/// need a shell to interpret them. Which shell differs per platform; nothing
/// above this type needs to know that.
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

  /// A multi-line script, run so its first failing line ends it and is the
  /// one reported. The POSIX family takes `set -e`; fish and the csh family
  /// have no such switch and run the script as written. `shellPath` names
  /// the shell to run it through, as an interactive login shell; `nil` is
  /// `$SHELL`.
  ///
  /// A failure's message is everything the script itself printed: stdout,
  /// then stderr, since a hook's `echo` is as much its account of what went
  /// wrong as its errors are. The rc files run first and some write to
  /// stderr under `-i` with no terminal (`can't change option: zle`), so the
  /// script's first line writes a marker there and its stderr is taken from
  /// after it.
  public func runScript(
    _ script: String,
    in directory: URL,
    environment: [String: String] = [:],
    shellPath: String? = nil
  ) async throws -> String {
    guard let shell = Self.shell(preferring: shellPath) else { throw ShellUnavailable() }
    let prepared = Self.markingOutput(
      Self.stoppingAtFirstFailure(script, shell: shell.executable), shell: shell.executable)
    let arguments = shell.arguments + [prepared]
    let output = try await runner.capture(
      shell.executable, arguments, in: directory, environment: environment)
    guard output.succeeded else {
      throw ProcessFailure(
        executable: shell.executable.lastPathComponent, arguments: arguments,
        status: output.status,
        message: Self.failureMessage(
          standardOutput: output.standardOutput, standardError: output.standardError))
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
  /// the script, after the rc files have run, so a chatty `.zshrc` is not
  /// what stops it.
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
  /// shell that wrote none.
  static func scriptOutput(fromStderr text: String) -> String {
    guard let marker = text.range(of: outputMarker) else { return text }
    return String(text[marker.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The user's shell as an interactive login shell, so a hook sees the
  /// PATH a terminal in this app sees. An app launched from the Finder has
  /// only the system directories, and `npm` or `mise` live elsewhere; the
  /// additions are in `.zprofile` for some people and `.zshrc` for others,
  /// so both `-l` and `-i` are needed. `/bin/sh` when `$SHELL` is unset or
  /// missing, as in a sandbox.
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
