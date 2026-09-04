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

  private static var shell: (executable: URL, arguments: [String])? {
    #if os(Windows)
      guard let cmd = ExecutableLookup.find("cmd") else { return nil }
      return (cmd, ["/c"])
    #else
      // $SHELL is the user's interactive shell, which may not exist in a
      // sandboxed environment; /bin/sh is guaranteed by POSIX.
      return (URL(fileURLWithPath: "/bin/sh"), ["-c"])
    #endif
  }
}

public struct ShellUnavailable: Error, CustomStringConvertible {
  public var description: String { "no shell available to run hooks" }
}
