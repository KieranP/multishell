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

  /// The user's shell as an interactive login shell, so a hook sees the
  /// PATH a terminal in this app sees. An app launched from the Finder has
  /// only the system directories, and `npm` or `mise` live elsewhere; the
  /// additions are in `.zprofile` for some people and `.zshrc` for others,
  /// so both `-l` and `-i` are needed. `/bin/sh` when `$SHELL` is unset or
  /// missing, as in a sandbox.
  public static var shell: (executable: URL, arguments: [String])? {
    #if os(Windows)
      guard let cmd = ExecutableLookup.find("cmd") else { return nil }
      return (cmd, ["/c"])
    #else
      return shell(named: ProcessInfo.processInfo.environment["SHELL"])
    #endif
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
