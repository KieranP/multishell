import Foundation
import TestScratch

@testable import MultishellCore
@testable import MultishellProcess

/// The files and variables a terminal tab starts its shell with, pointed at
/// the built helper unless a test stands another in.
enum ShellTab {
  static func bashInitFile(in home: URL, helper: URL? = nil) throws -> URL {
    let file = home.appendingPathComponent("init.bash")
    try ShellIntegrationScripts.forBash(helper: (try helper ?? HelperBinary.require()).path)
      .write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  static func zshIntegrationDirectory(in root: URL, helper: URL? = nil) throws -> URL {
    let directory = root.appendingPathComponent("integration", isDirectory: true)
    try ShellIntegration.refresh(
      zshDirectory: directory, bashInit: root.appendingPathComponent("bash/init.bash"),
      helper: (try helper ?? HelperBinary.require()).path)
    return directory
  }

  static func environment(
    socket: URL, session: UUID = UUID(), home: URL? = nil, worktree: String? = nil
  ) -> [String: String] {
    var environment = Scratch.shellEnvironment
    if let home { environment["HOME"] = home.path }
    environment["MULTISHELL_SOCKET"] = socket.path
    environment["MULTISHELL_SESSION"] = session.uuidString
    if let worktree { environment["MULTISHELL_WORKTREE"] = worktree }
    return environment
  }

  /// An empty directory to stand for the user's own `ZDOTDIR`, so the chain
  /// reaches none of the developer's files.
  static func userZdotdir(in root: URL) throws -> URL {
    let directory = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  static func zshEnvironment(
    socket: URL, session: UUID = UUID(), home: URL? = nil, worktree: String? = nil,
    integration: URL, userZdotdir: URL
  ) -> [String: String] {
    var environment = environment(socket: socket, session: session, home: home, worktree: worktree)
    environment["ZDOTDIR"] = integration.path
    environment["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    return environment
  }

  /// `script` run by an interactive bash under the generated init, as a tab's would be.
  static func runBash(
    _ bash: String = "/bin/bash", initFile: URL, script: String, in home: URL,
    environment: [String: String], timeout: Duration? = nil
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: environment, timeout: timeout)
  }

  /// `script` run by an interactive zsh, a login one where `isLogin`.
  static func runZsh(
    _ script: String, isLogin: Bool = false, in directory: URL, environment: [String: String]
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), (isLogin ? ["-l"] : []) + ["-i", "-c", script],
      in: directory, environment: environment)
  }

  /// An interactive bash under the generated init reading `script` as its
  /// input, typed at its prompt rather than handed over with `-c`.
  static func runBash(
    _ bash: String, initFile: URL, feeding script: URL, in home: URL,
    environment: [String: String]
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/sh"),
      [
        "-c",
        "exec \(bash) --init-file \(PosixShellQuoting.quote(initFile.path)) -i "
          + "< \(PosixShellQuoting.quote(script.path))",
      ], in: home, environment: environment)
  }
}
