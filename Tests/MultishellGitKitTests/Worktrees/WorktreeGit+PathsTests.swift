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
      at: link,
      withDestinationURL: root.appendingPathComponent("nowhere"),
    )
    let resolvedRoot = try #require(Scratch.physicalPath(of: root))

    #expect(
      WorktreeGit.pathAsGitLists(link.appendingPathComponent("wt"))
        == resolvedRoot + "/link/wt"
    )
  }

  @Test func aGitFileNamesItsDirectoryWhateverItsLineEndingOrALineSeparatorInThePath() throws {
    let root = try Scratch.directory("git-file")
    defer { Scratch.remove(root) }
    let file = root.appendingPathComponent(".git")
    for (text, expected) in [
      ("gitdir: /a/b\r\n", "/a/b"), ("gitdir: /a/x\u{2028}y\n", "/a/x\u{2028}y"),
    ] {
      try text.write(to: file, atomically: true, encoding: .utf8)
      let directory = WorktreeGit.directoryNamed(inFile: file, relativeTo: root, after: "gitdir: ")
      #expect(directory?.path == expected, "\(text.debugDescription)")
    }
  }
}
