import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite @MainActor
struct PartialStateTests {
  /// The dropped tab has a pane kind this build does not know; the session it owned goes
  /// with it.
  @Test func aStateFileWithOneUnreadableTabRestoresEverythingElse() throws {
    let file = Scratch.path("scratch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

    let kept = UUID()
    let orphaned = UUID()
    let keptTab = UUID()
    try Data(
      #"""
      { "projects": [ { "path": "file:///repos/demo/" } ],
        "worktrees": [ { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a" } ],
        "sessions": [
          { "id": "\#(kept)", "worktreeID": "/repos/demo", "workingDirectory": "file:///repos/demo/", "title": "sh" },
          { "id": "\#(orphaned)", "worktreeID": "/repos/demo", "workingDirectory": "file:///repos/demo/", "title": "sh" } ],
        "tabs": [
          { "id": "\#(keptTab)", "worktreeID": "/repos/demo", "focusedSessionID": "\#(kept)",
            "root": { "terminal": { "_0": "\#(kept)" } } },
          { "id": "\#(UUID())", "worktreeID": "/repos/demo", "focusedSessionID": "\#(orphaned)",
            "root": { "stack": { "pages": [ { "terminal": { "_0": "\#(orphaned)" } } ] } } } ],
        "activeTabByWorktree": { "/repos/demo": "\#(keptTab)" } }
      """#.utf8
    ).write(to: file)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))

    #expect(error == nil, "\(String(describing: error))")
    #expect(store.workspace.projects.map(\.name) == ["demo"])
    #expect(store.workspace.tabs.map(\.id) == [keptTab])
    #expect(store.workspace.sessions.map(\.id) == [kept])
    #expect(store.workspace.activeTab(in: "/repos/demo")?.id == keptTab)
    WorkspaceInvariants.check(store.workspace, "restored")
    #expect(FileManager.default.fileExists(atPath: file.path), "nothing was moved aside")
  }
}
