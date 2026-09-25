import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A hand edit or two spellings of one path can list an entry twice, and the New Worktree
/// picker's labels are a dictionary that traps on a repeat.
extension WorkspaceRepairTests {
  /// The same as the tab case below, one collection up: the dead copy is the
  /// one kept, the prune then drops it, and its tabs and sessions go too.
  @Test func aWorktreeIdListedTwiceKeepsTheCopyWhoseProjectIsStillThere() throws {
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [ { "path": "file:///repos/demo/" } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/gone", "head": "a", "branch": "dead" },
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "live" } ] }
        """#.utf8))
    #expect(ws.worktrees.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate worktree")
    #expect(ws.worktrees.map(\.branch) == ["live"], "the dead copy was kept and then pruned")
  }

  /// First entry wins, so deduping before the dangling prune can keep the
  /// copy naming a worktree that has gone and lose the live one with it.
  @Test func aTabIdListedTwiceKeepsTheCopyWhoseWorktreeIsStillThere() throws {
    let tab = UUID().uuidString
    let dead = UUID().uuidString
    let live = UUID().uuidString
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [ { "path": "file:///repos/demo/" } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ],
          "tabs": [
            { "id": "\#(tab)", "worktreeID": "/repos/gone",
              "root": { "terminal": { "_0": "\#(dead)" } }, "focusedSessionID": "\#(dead)" },
            { "id": "\#(tab)", "worktreeID": "/repos/demo",
              "root": { "terminal": { "_0": "\#(live)" } }, "focusedSessionID": "\#(live)" } ],
          "sessions": [
            { "id": "\#(live)", "worktreeID": "/repos/demo",
              "workingDirectory": "file:///repos/demo/", "title": "Shell" } ] }
        """#.utf8))
    #expect(ws.tabs.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate tab")
    #expect(ws.tabs.map(\.worktreeID) == ["/repos/demo"], "the dead copy was kept and then pruned")
    #expect(ws.sessions.map(\.id.uuidString) == [live], "its session went with it")
  }

  @Test func aProjectListedTwiceKeepsItsFirstEntryAndItsWorktrees() throws {
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [
            { "path": "file:///repos/demo/", "settings": { "branchPrefix": "k/" } },
            { "path": "file:///repos/x/../demo", "isExpanded": false } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" },
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ] }
        """#.utf8))
    #expect(ws.projects.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate project")
    #expect(ws.projects.map(\.id) == ["/repos/demo"])
    #expect(ws.projects[0].settings.branchPrefix == "k/", "the first entry is the one kept")
    #expect(ws.worktrees.map(\.id) == ["/repos/demo"])
  }
}
