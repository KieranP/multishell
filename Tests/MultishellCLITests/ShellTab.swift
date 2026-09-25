import Foundation
import TestScratch

@testable import MultishellCore

/// The files and variables a terminal tab starts its shell with, pointed at
/// the built helper unless a test stands another in.
enum ShellTab {
  static func bashInitFile(in home: URL, helper: URL? = nil) throws -> URL {
    let file = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitScript(helper: (try helper ?? HelperBinary.require()).path)
      .write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  static func zshIntegrationDirectory(in root: URL, helper: String? = nil) throws -> URL {
    let directory = root.appendingPathComponent("integration", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let files = ShellStateHooks.zshIntegrationScripts(
      helper: try helper ?? HelperBinary.require().path)
    for (name, contents) in files {
      try contents.write(
        to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
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
}
