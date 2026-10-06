import Foundation
import TestScratch

@testable import MultishellCore

/// The integration files as the app writes them, beside a home with no startup
/// file, so a shell run against them reads nothing this machine has.
struct GeneratedIntegration {
  let root: URL
  let home: URL
  let zshDirectory: URL
  let bashInit: URL

  init(helper: String) throws {
    root = Scratch.path("marks")
    home = root.appendingPathComponent("home", isDirectory: true)
    zshDirectory = root.appendingPathComponent("zsh", isDirectory: true)
    bashInit = root.appendingPathComponent("bash/init.bash")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try ShellIntegration.refresh(zshDirectory: zshDirectory, bashInit: bashInit, helper: helper)
  }

  func tearDown() {
    Scratch.remove(root)
  }

  func writeHomeFile(_ name: String, _ contents: String) throws {
    try Data(contents.utf8).write(to: home.appendingPathComponent(name), options: .atomic)
  }

  func environment(termProgram: String?) -> [String: String] {
    var environment = ["HOME": home.path, "PATH": "/usr/bin:/bin", "TERM": "dumb"]
    environment["TERM_PROGRAM"] = termProgram
    return environment
  }
}
