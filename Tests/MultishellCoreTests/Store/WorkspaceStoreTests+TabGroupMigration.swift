import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A state file from before groups: tabs name no group, and the active tab per worktree
/// sits under a key this build no longer has a property for.
extension WorkspaceStoreTests {
  @Test func aStateFileWrittenBeforeTabGroupsComesBackAsOneGroupPerWorktree() throws {
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
    let group = ws.groups(in: "/repos/demo")[0]
    #expect(ws.tabs(in: group.id).map(\.id) == [shellTab, agentTab, splitTab])

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

}
