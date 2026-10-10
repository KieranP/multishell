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

  static func fishInitFile(in home: URL) throws -> URL {
    let file = home.appendingPathComponent("init.fish")
    try ShellIntegrationScripts.forFish(helper: try HelperBinary.require().path)
      .write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  static func zshIntegrationDirectory(in root: URL) throws -> URL {
    let directory = root.appendingPathComponent("integration", isDirectory: true)
    try ShellIntegration.refresh(
      zshDirectory: directory,
      bashInit: root.appendingPathComponent("bash/init.bash"),
      fishInit: root.appendingPathComponent("fish/init.fish"),
      helper: try HelperBinary.require().path,
    )
    return directory
  }

  static func environment(
    socket: URL,
    session: UUID = UUID(),
    home: URL? = nil,
    worktree: String? = nil,
  ) -> [String: String] {
    var environment = Scratch.shellEnvironment
    if let home { environment["HOME"] = home.path }
    environment["MULTISHELL_SOCKET"] = socket.path
    environment["MULTISHELL_SESSION"] = session.uuidString
    if let worktree { environment["MULTISHELL_WORKTREE"] = worktree }
    return environment
  }

  /// fish finds its config through XDG before `HOME`, so a developer's own
  /// would otherwise run in the test's shell.
  static func fishEnvironment(
    socket: URL,
    home: URL,
    session: UUID = UUID(),
    worktree: String? = nil,
  ) -> [String: String] {
    var environment = environment(socket: socket, session: session, home: home, worktree: worktree)
    environment["XDG_CONFIG_HOME"] = home.appendingPathComponent(".config").path
    environment["XDG_DATA_HOME"] = home.appendingPathComponent(".local/share").path
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
    socket: URL,
    integration: URL,
    userZdotdir: URL,
    session: UUID = UUID(),
    worktree: String? = nil,
  ) -> [String: String] {
    var environment = environment(socket: socket, session: session, worktree: worktree)
    environment["ZDOTDIR"] = integration.path
    environment["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    return environment
  }

  /// `script` run by an interactive bash under the generated init, as a tab's would be.
  static func runBash(
    initFile: URL,
    script: String,
    in home: URL,
    environment: [String: String],
    bash: String = "/bin/bash",
    timeout: Duration? = nil,
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: bash),
      ["--init-file", initFile.path, "-i", "-c", script],
      in: home,
      environment: environment,
      timeout: timeout,
    )
  }

  /// `script` run by an interactive zsh.
  static func runZsh(
    _ script: String,
    in directory: URL,
    environment: [String: String],
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-i", "-c", script],
      in: directory,
      environment: environment,
    )
  }

  /// `script` run by an interactive fish under the generated init. fish fires
  /// its command events only at a real prompt, so the script emits them.
  static func runFish(
    _ fish: String,
    initFile: URL,
    script: String,
    in home: URL,
    environment: [String: String],
  ) async throws -> ProcessOutput {
    let launch = ShellLaunch.fishInitArguments(forShell: fish, fishInit: initFile)
    return try await ProcessRunner().capture(
      URL(fileURLWithPath: fish),
      Array(launch.dropFirst()) + ["-i", "-c", script],
      in: home,
      environment: environment,
    )
  }

  /// An interactive bash under the generated init reading `script` as its
  /// input, typed at its prompt rather than handed over with `-c`.
  static func runBash(
    initFile: URL,
    feeding script: URL,
    in home: URL,
    environment: [String: String],
    bash: String,
  ) async throws -> ProcessOutput {
    try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/sh"),
      [
        "-c",
        "exec \(bash) --init-file \(AnyShellQuoting.quote(initFile.path)) -i "
          + "< \(AnyShellQuoting.quote(script.path))",
      ],
      in: home,
      environment: environment,
    )
  }
}
