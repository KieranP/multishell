import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct DeleteDirectoryTests {
  @Test func deletingAWorktreeOutrightLeavesWhatItsLinksPointAt() async throws {
    let main = try Scratch.directory("linked-main")
    defer { Scratch.remove(main) }
    let modules = main.appendingPathComponent("node_modules")
    try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
    try "x".write(to: modules.appendingPathComponent("a.js"), atomically: true, encoding: .utf8)
    let worktree = try Scratch.directory("linked-worktree")
    defer { Scratch.remove(worktree) }
    try FileManager.default.createSymbolicLink(
      at: worktree.appendingPathComponent("node_modules"), withDestinationURL: modules)

    try await deleteDirectory(worktree)

    #expect(!FileManager.default.fileExists(atPath: worktree.path))
    #expect(FileManager.default.fileExists(atPath: modules.appendingPathComponent("a.js").path))
  }
}
