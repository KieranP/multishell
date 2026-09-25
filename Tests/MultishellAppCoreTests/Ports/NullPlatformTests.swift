import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct NullPlatformTests {
  @Test func withoutATrashARemovedDirectoryIsDeleted() throws {
    let directory = try Scratch.directory("null")
    try "x".write(to: directory.appendingPathComponent("f"), atomically: true, encoding: .utf8)

    try NullPlatform().moveToTrash(directory)

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }

  @Test func deletingAWorktreeOutrightLeavesWhatItsLinksPointAt() async throws {
    let main = try Scratch.directory("linked-main")
    let modules = main.appendingPathComponent("node_modules")
    try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
    try "x".write(to: modules.appendingPathComponent("a.js"), atomically: true, encoding: .utf8)
    let worktree = try Scratch.directory("linked-worktree")
    try FileManager.default.createSymbolicLink(
      at: worktree.appendingPathComponent("node_modules"), withDestinationURL: modules)

    try await AppModel<FakeSurface>.delete(worktree)

    #expect(!FileManager.default.fileExists(atPath: worktree.path))
    #expect(FileManager.default.fileExists(atPath: modules.appendingPathComponent("a.js").path))
  }
}
