import Foundation
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitPathsTests {
  @Test func aPathBelowADanglingLinkResolvesItsParentsAsGitDoes() throws {
    let root = try Scratch.directory("dangling")
    defer { Scratch.remove(root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: root.appendingPathComponent("nowhere"))
    let resolvedRoot = try #require(Scratch.physicalPath(of: root))

    #expect(
      WorktreeGit.pathAsGitLists(link.appendingPathComponent("wt"))
        == resolvedRoot + "/link/wt")
  }
}
