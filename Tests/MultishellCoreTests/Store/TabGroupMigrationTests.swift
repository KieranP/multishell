import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A state file from before columns: tabs name no column, and the active tab per worktree
/// sits under a key this build no longer has a property for.
@Suite @MainActor
struct TabGroupMigrationTests {
  @Test func aStateFileWrittenBeforeColumnsComesBackAsOneColumnPerWorktree() throws {
    let file = Scratch.path("scratch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

    let (shell, agent, left, right, lonely) = (UUID(), UUID(), UUID(), UUID(), UUID())
    let (shellTab, agentTab, splitTab, featureTab) = (UUID(), UUID(), UUID(), UUID())
    func session(_ id: UUID, _ worktree: String, _ title: String) -> String {
      """
      { "id": "\(id)", "worktreeID": "\(worktree)", "title": "\(title)",
        "workingDirectory": "file://\(worktree)/" }
      """
    }
    try Data(
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [
          { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" },
          { "path": "file:///repos/demo-feat/", "projectID": "/repos/demo", "head": "b", "branch": "feat" } ],
        "sessions": [
          \#(session(shell, "/repos/demo", "zsh")),
          \#(session(agent, "/repos/demo", "claude")),
          \#(session(left, "/repos/demo", "left")),
          \#(session(right, "/repos/demo", "right")),
          \#(session(lonely, "/repos/demo-feat", "zsh")) ],
        "tabs": [
          { "id": "\#(shellTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(shell)",
            "root": { "terminal": { "_0": "\#(shell)" } } },
          { "id": "\#(agentTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(agent)",
            "customTitle": "build", "root": { "terminal": { "_0": "\#(agent)" } } },
          { "id": "\#(splitTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(right)",
            "root": { "split": { "axis": "horizontal", "weights": [3, 1], "children": [
              { "terminal": { "_0": "\#(left)" } }, { "terminal": { "_0": "\#(right)" } } ] } } },
          { "id": "\#(featureTab)", "worktreeID": "/repos/demo-feat", "focusedSessionID": "\#(lonely)",
            "root": { "terminal": { "_0": "\#(lonely)" } } } ],
        "activeTabByWorktree": { "/repos/demo": "\#(agentTab)" } }
      """#.utf8
    ).write(to: file)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))
    let ws = store.workspace

    #expect(error == nil, "\(String(describing: error))")
    WorkspaceInvariants.check(ws, "migrated")

    #expect(ws.groups(in: "/repos/demo").count == 1)
    #expect(ws.groups(in: "/repos/demo-feat").count == 1)
    let column = ws.groups(in: "/repos/demo")[0]
    #expect(ws.tabs(in: column.id).map(\.id) == [shellTab, agentTab, splitTab])

    // What the user was looking at, which is the whole reason the old key is
    // still read.
    #expect(ws.activeTab(in: "/repos/demo")?.id == agentTab)
    #expect(ws.activeTab(in: "/repos/demo-feat")?.id == featureTab, "its only tab")

    #expect(ws.tab(agentTab)?.customTitle == "build")
    #expect(ws.tab(splitTab)?.isSplit == true)
    #expect(ws.tab(splitTab)?.focusedSessionID == right)
    #expect(ws.sessions.count == 5)
    #expect(ws.groups(in: "/repos/demo")[0].weight == 1)
  }

  @Test func theMigratedStateIsWhatIsSavedFromThenOn() throws {
    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    let session = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
    var group = TabGroup(worktreeID: worktree.id)
    let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: session.id)
    group.activeTabID = tab.id
    workspace.projects = [project]
    workspace.worktrees = [worktree]
    workspace.sessions = [session]
    workspace.tabs = [tab]
    workspace.tabGroups = [group]
    workspace.focusedGroupByWorktree = [worktree.id: group.id]

    let json = String(decoding: try JSONEncoder().encode(workspace), as: UTF8.self)
    #expect(json.contains("tabGroups"))
    #expect(json.contains("focusedGroupByWorktree"))
    #expect(!json.contains("activeTabByWorktree"), "the old key is read, never written")

    var reloaded = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
    reloaded.repairReferences()
    #expect(reloaded == workspace, "a saved layout comes back exactly")
  }
}
