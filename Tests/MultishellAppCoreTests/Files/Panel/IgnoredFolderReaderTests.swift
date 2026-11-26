import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct IgnoredFolderReaderTests {
  private struct LinkedWorktree {
    let root: URL
    let worktree: URL

    init() throws {
      root = try Scratch.directory("ignored-links")
      worktree = root.appending(path: "worktree", directoryHint: .isDirectory)
      let files = FileManager.default
      let outside = root.appending(path: "outside", directoryHint: .isDirectory)
      try files.createDirectory(at: outside, withIntermediateDirectories: true)
      try "away\n".write(to: outside.appending(path: "f.txt"), atomically: true, encoding: .utf8)
      let inside = worktree.appending(path: "build/real", directoryHint: .isDirectory)
      try files.createDirectory(at: inside, withIntermediateDirectories: true)
      try files.createSymbolicLink(
        atPath: worktree.appending(path: "build/out").path,
        withDestinationPath: outside.path,
      )
      try files.createSymbolicLink(
        atPath: worktree.appending(path: "build/near").path,
        withDestinationPath: "real",
      )
    }
  }

  @Test func aLinkToAFolderOutsideTheWorktreeIsListedAsNoFolder() throws {
    let linked = try LinkedWorktree()
    defer { Scratch.remove(linked.root) }

    let entries = IgnoredFolderReader.entries(of: "build", in: linked.worktree)

    #expect(entries.first { $0.name == "out" }?.isFolder == false)
    #expect(entries.first { $0.name == "near" }?.isFolder == true, "it stays in the worktree")
    #expect(entries.first { $0.name == "real" }?.isFolder == true)
  }

  @Test func aFolderReachedThroughALinkLeavingTheWorktreeListsNothing() throws {
    let linked = try LinkedWorktree()
    defer { Scratch.remove(linked.root) }

    #expect(IgnoredFolderReader.entries(of: "build/out", in: linked.worktree).isEmpty)
  }
}
