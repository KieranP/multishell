import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct GitExecutableTests {
  @Test func theShimIsResolvedThroughXcrunToTheGitItRuns() async throws {
    let root = try Scratch.directory("git-executable")
    defer { Scratch.remove(root) }
    let shim = try Scratch.script("exit 0", at: root.appendingPathComponent("git"))
    let real = try Scratch.script("exit 0", at: root.appendingPathComponent("real-git"))
    let xcrun = try Scratch.script(
      "echo '\(real.path)'",
      at: root.appendingPathComponent("xcrun"),
    )

    let found = await GitExecutable.resolve(
      searchPath: root.path,
      developerDirectory: root,
      shim: shim,
      xcrun: xcrun,
    )

    #expect(found?.path == real.path)
  }

  @Test func anXcrunThatFailsLeavesTheShim() async throws {
    let root = try Scratch.directory("git-executable")
    defer { Scratch.remove(root) }
    let shim = try Scratch.script("exit 0", at: root.appendingPathComponent("git"))
    let xcrun = try Scratch.script("exit 1", at: root.appendingPathComponent("xcrun"))

    let found = await GitExecutable.resolve(
      searchPath: root.path,
      developerDirectory: root,
      shim: shim,
      xcrun: xcrun,
    )

    #expect(found?.path == shim.path)
  }

  @Test func aGitThatIsNotTheShimIsUsedAsFoundAndXcrunIsNotRun() async throws {
    let root = try Scratch.directory("git-executable")
    defer { Scratch.remove(root) }
    let git = try Scratch.script("exit 0", at: root.appendingPathComponent("git"))
    let marker = root.appendingPathComponent("ran")
    let xcrun = try Scratch.script(
      "touch '\(marker.path)'",
      at: root.appendingPathComponent("xcrun"),
    )

    let found = await GitExecutable.resolve(
      searchPath: root.path,
      developerDirectory: root,
      shim: URL(fileURLWithPath: "/usr/bin/git"),
      xcrun: xcrun,
    )

    #expect(found?.path == git.path)
    #expect(!FileManager.default.fileExists(atPath: marker.path))
  }

  @Test func withNoDeveloperToolsXcrunIsNotAskedAndTheShimStays() async throws {
    let root = try Scratch.directory("git-executable")
    defer { Scratch.remove(root) }
    let shim = try Scratch.script("exit 0", at: root.appendingPathComponent("git"))
    let marker = root.appendingPathComponent("ran")
    let xcrun = try Scratch.script(
      "touch '\(marker.path)'",
      at: root.appendingPathComponent("xcrun"),
    )

    let found = await GitExecutable.resolve(
      searchPath: root.path,
      developerDirectory: root.appendingPathComponent("CommandLineTools"),
      shim: shim,
      xcrun: xcrun,
    )

    #expect(found?.path == shim.path)
    #expect(!FileManager.default.fileExists(atPath: marker.path))
  }
}
