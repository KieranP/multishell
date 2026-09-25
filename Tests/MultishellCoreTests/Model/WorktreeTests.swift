import Foundation
import Testing

@testable import MultishellCore

struct WorktreeTests {
  @Test func worktreeURLsDecodeAsDirectories() throws {
    // Written by an older build without the trailing slash Foundation uses
    // for directories. Identity and relative resolution must not change.
    let worktree = try decodeJSON(
      Worktree.self,
      #"{ "path": "file:///repos/demo", "projectID": "/repos/demo", "head": "abc", "isPrimary": true, "isLocked": false }"#
    )
    #expect(worktree.id == "/repos/demo")
    #expect(worktree.branch == nil)
    #expect(worktree.isDetached)
    #expect(worktree.path.hasDirectoryPath)
  }

  /// The date is read off the filesystem at discovery, so state written
  /// before the field existed simply has none.
  @Test func aWorktreeWithoutACreationDateHasNone() throws {
    let worktree = try decodeJSON(
      Worktree.self,
      #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc" }"#)
    #expect(worktree.createdAt == nil)

    let dated = try decodeJSON(
      Worktree.self,
      #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc", "createdAt": 1000 }"#
    )
    #expect(dated.createdAt == Date(timeIntervalSinceReferenceDate: 1000))
  }

  /// Worktrees decode lossily, so throwing over a date would drop the row,
  /// the tabs saved under it, and the neighbours in the same list.
  @Test func aWorktreeWithAnUnreadableDateKeepsEverythingElse() throws {
    let odd = try decodeJSON(
      Worktree.self,
      #"""
      { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "abc",
        "createdAt": "2026-09-08T00:00:00Z" }
      """#)
    #expect(odd.createdAt == nil)
    #expect(odd.id == "/repos/demo", "the worktree itself still loads")

    let workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a",
            "createdAt": "nonsense" },
          { "path": "file:///repos/demo-feat/", "projectID": "/repos/demo", "head": "b",
            "createdAt": 1000 }
        ] }
      """#)
    #expect(workspace.worktrees.count == 2)
    #expect(workspace.worktrees[0].createdAt == nil)
    #expect(workspace.worktrees[1].createdAt == Date(timeIntervalSinceReferenceDate: 1000))
  }

  @Test func aWorktreeWithoutTheBareFlagIsNotBare() throws {
    let worktree = try decodeJSON(
      Worktree.self, #"{ "path": "file:///repos/demo/", "projectID": "/repos/demo" }"#)
    #expect(!worktree.isBare)
    let bare = try decodeJSON(
      Worktree.self,
      #"{ "path": "file:///repos/demo.git/", "projectID": "/repos/demo.git", "isBare": true }"#)
    #expect(bare.isBare && !bare.isDetached)
    #expect(bare.name == "demo.git", "a bare entry has no branch and no HEAD to name it by")
  }
}
