import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  /// Moving it aside frees the path to write. Where that fails too the state
  /// is still there; see Docs/design/state-and-store.md.
  @Test func aStateFileMovedAwayMidSessionLetsSavingResume() throws {
    let file = try scratchStateFile(holding: #"{"projects":[{"path":"file:///repos/demo/"}]}"#)
    let directory = file.deletingLastPathComponent()
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      Scratch.remove(directory)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: directory.path)
    let (store, _) = WorkspaceStore.restored(from: StateFile(fileURL: file))
    #expect(store.refusesToSave)

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: directory.path)
    try FileManager.default.moveItem(at: file, to: directory.appendingPathComponent("kept.json"))
    store.addProject(at: URL(fileURLWithPath: "/repos/other"))
    try store.save()

    #expect(!store.refusesToSave)
    let saved = try StateFile(fileURL: file).load()
    #expect(saved.projects.map(\.path.path) == ["/repos/other"])
  }

  @Test func aStateFileThatCannotBeMovedAsideIsNeverSavedOver() throws {
    let original = #"{"projects":[{"path":"file:///repos/demo/"}]}"#
    let file = try scratchStateFile(holding: original)
    let directory = file.deletingLastPathComponent()
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      Scratch.remove(directory)
    }
    // Unreadable, and in a directory that takes no rename, so neither the
    // read nor the move aside can happen.
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: directory.path)

    let (store, loadError) = WorkspaceStore.restored(from: StateFile(fileURL: file))

    #expect(loadError is UnmovableStateFile)
    #expect(store.refusesToSave)
    #expect(store.workspace.projects.isEmpty, "it did start empty; that is the danger")
    store.addProject(at: URL(fileURLWithPath: "/repos/other"))
    #expect(throws: Never.self) { try store.save() }

    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
    #expect(
      try String(contentsOf: file, encoding: .utf8) == original,
      "the user's own state is still on disk, untouched")
  }

  @Test func restoringRepairsDanglingReferencesBeforeTheStoreSeesThem() throws {
    let file = scratchStatePath()
    defer { Scratch.remove(file.deletingLastPathComponent()) }

    var workspace = Workspace()
    let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(path: project.path, projectID: project.id, head: "a", branch: "main")
    workspace.projects = [project]
    workspace.worktrees = [
      worktree,
      Worktree(path: URL(fileURLWithPath: "/repos/orphan"), projectID: "/repos/gone", head: "b"),
    ]
    let orphan = TerminalSession(
      worktreeID: worktree.id, workingDirectory: worktree.path, title: "x")
    workspace.sessions = [orphan]
    try StateFile(fileURL: file).save(workspace)

    let (store, error) = WorkspaceStore.restored(from: StateFile(fileURL: file))

    #expect(error == nil)
    #expect(store.workspace.worktrees.map(\.id) == [worktree.id])
    #expect(
      store.workspace.sessions.isEmpty,
      "a session no tab shows would get a shell nobody can close")
  }

  /// The dropped tab has a pane kind this build does not know; the session it owned goes
  /// with it.
  @Test func aStateFileWithOneUnreadableTabRestoresEverythingElse() throws {
    let kept = UUID()
    let orphaned = UUID()
    let keptTab = UUID()
    let file = try scratchStateFile(
      holding:
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
        """#)
    defer { Scratch.remove(file.deletingLastPathComponent()) }

    let (store, error) = WorkspaceStore.restored(from: StateFile(fileURL: file))

    #expect(error == nil, "\(String(describing: error))")
    #expect(store.workspace.projects.map(\.name) == ["demo"])
    #expect(store.workspace.tabs.map(\.id) == [keptTab])
    #expect(store.workspace.sessions.map(\.id) == [kept])
    #expect(store.workspace.activeTab(in: "/repos/demo")?.id == keptTab)
    WorkspaceInvariants.check(store.workspace, "restored")
    #expect(FileManager.default.fileExists(atPath: file.path), "nothing was moved aside")
  }
}
