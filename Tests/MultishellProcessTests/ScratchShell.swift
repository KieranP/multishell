import Foundation
import TestScratch

/// A shell named outright, over a home the test owns, so no test here reads
/// the developer's `$SHELL` or rc files.
struct ScratchShell {
  let path: String
  let home: URL

  init(_ path: String = "/bin/zsh") throws {
    self.path = path
    home = try Scratch.directory("home")
  }

  var environment: [String: String] { ["HOME": home.path, "ZDOTDIR": home.path] }

  func tearDown() {
    try? FileManager.default.removeItem(at: home)
  }
}
