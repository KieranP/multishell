import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellGitKit

extension WorktreeGitTests {
  @Test func aPathBelowADanglingLinkResolvesItsParentsAsGitDoes() throws {
    let root = try Scratch.directory("dangling")
    defer { Scratch.remove(root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: root.appendingPathComponent("nowhere"))
    let resolvedRoot = try #require(realpath(root.path, nil))
    defer { free(resolvedRoot) }

    #expect(
      WorktreeGit.realPath(of: link.appendingPathComponent("wt"))
        == String(cString: resolvedRoot) + "/link/wt")
  }
}
