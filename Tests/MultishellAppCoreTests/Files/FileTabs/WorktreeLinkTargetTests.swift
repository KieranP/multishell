import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeLinkTargetTests {
  @Test func aPathUnderADanglingFolderLinkLeadsNowhere() throws {
    let root = try Scratch.directory("link-target")
    defer { Scratch.remove(root) }
    let worktree = root.appending(path: "worktree", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: worktree.appending(path: "out"),
      withDestinationURL: root.appending(path: "missing"),
    )

    #expect(WorktreeLinkTarget.path(of: "out/x", in: worktree) == nil)
  }

  @Test func aPathUnderAFolderLinkInsideTheWorktreeIsItself() throws {
    let root = try Scratch.directory("link-target")
    defer { Scratch.remove(root) }
    let worktree = root.appending(path: "worktree", directoryHint: .isDirectory)
    let real = worktree.appending(path: "real", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    try "x\n".write(to: real.appending(path: "f.txt"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      atPath: worktree.appending(path: "inner").path,
      withDestinationPath: "real",
    )
    try FileManager.default.createSymbolicLink(
      atPath: worktree.appending(path: "f-link.txt").path,
      withDestinationPath: "inner/f.txt",
    )

    #expect(WorktreeLinkTarget.path(of: "inner/f.txt", in: worktree) == "inner/f.txt")
    #expect(WorktreeLinkTarget.path(of: "inner/gone.txt", in: worktree) == "inner/gone.txt")
    #expect(WorktreeLinkTarget.path(of: "f-link.txt", in: worktree) == "real/f.txt")
  }
}
