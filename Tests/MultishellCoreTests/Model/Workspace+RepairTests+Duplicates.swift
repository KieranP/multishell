import Foundation
import Testing

@testable import MultishellCore

/// A hand edit or two spellings of one path can list an entry twice, and the New Worktree
/// picker's labels are a dictionary that traps on a repeat.
extension WorkspaceRepairTests {
  /// The same as the tab case below, one collection up: the dead copy is the
  /// one kept, the prune then drops it, and its tabs and sessions go too.
  @Test func aWorktreeIdListedTwiceKeepsTheCopyWhoseProjectIsStillThere() throws {
    var workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/gone", "head": "a", "branch": "dead" },
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "live" } ] }
      """#)
    #expect(workspace.worktrees.count == 2, "decoding keeps both; repair is where they meet")

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "duplicate worktree")
    #expect(workspace.worktrees.map(\.branch) == ["live"], "the dead copy was kept and then pruned")
  }

  /// First entry wins, so deduping before the dangling prune can keep the
  /// copy naming a worktree that has gone and lose the live one with it.
  @Test func aTabIdListedTwiceKeepsTheCopyWhoseWorktreeIsStillThere() throws {
    let tab = UUID()
    let dead = UUID()
    let live = UUID()
    var workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ],
        "tabs": [
          \#(tabJSON(id: tab, worktree: "/repos/gone", session: dead)),
          \#(tabJSON(id: tab, session: live)) ],
        "sessions": [
          { "id": "\#(live)", "worktreeID": "/repos/demo",
            "workingDirectory": "file:///repos/demo/", "title": "Shell" } ] }
      """#)
    #expect(workspace.tabs.count == 2, "decoding keeps both; repair is where they meet")

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "duplicate tab")
    #expect(
      workspace.tabs.map(\.worktreeID) == ["/repos/demo"], "the dead copy was kept and then pruned")
    #expect(workspace.sessions.map(\.id) == [live], "its session went with it")
  }

  @Test func aProjectListedTwiceKeepsItsFirstEntryAndItsWorktrees() throws {
    var workspace = try decodeJSON(
      Workspace.self,
      #"""
      { "projects": [
          { "path": "file:///repos/demo/", "settings": { "branchPrefix": "k/" } },
          { "path": "file:///repos/x/../demo", "isExpanded": false } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" },
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ] }
      """#)
    #expect(workspace.projects.count == 2, "decoding keeps both; repair is where they meet")

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "duplicate project")
    #expect(workspace.projects.map(\.id) == ["/repos/demo"])
    #expect(workspace.projects[0].settings.branchPrefix == "k/", "the first entry is the one kept")
    #expect(workspace.worktrees.map(\.id) == ["/repos/demo"])
  }
}
