import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct PersistenceTests {
  private func scratchFile() -> URL {
    Scratch.path("state").appendingPathComponent("state.json")
  }

  @Test func stateWrittenBeforeAFieldExistedStillLoads() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Only what the very first build wrote: no appearance, no engine, no tabs.
    try Data(
      """
      { "projects": [ { "path": "file:///repos/demo/" } ], "worktrees": [], "sessions": [] }
      """.utf8
    ).write(to: file)

    let workspace = try WorkspaceFile(fileURL: file).load()

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.appearance.themeID == Theme.multishellDark.id)
  }

  @Test func unreadableStateIsMovedAsideNotOverwritten() throws {
    let file = scratchFile()
    let directory = file.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: file)

    let stateFile = WorkspaceFile(fileURL: file)
    var reported: URL?
    do {
      _ = try stateFile.load()
      Issue.record("unreadable state loaded")
    } catch let state as UnreadableState {
      reported = state.backup
    }

    let survivors = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(survivors.contains { $0.hasSuffix(".broken.json") })
    #expect(
      FileManager.default.fileExists(atPath: reported?.path ?? ""),
      "the alert names the backup, so it must be the file that was written")
    #expect(
      try String(contentsOf: directory.appendingPathComponent(survivors[0]), encoding: .utf8)
        == "not json")
  }

  /// The decode path moved a file aside and the read path did not, so one
  /// that would not open was left where an empty workspace would be saved.
  @Test func stateThatWillNotOpenIsMovedAsideAsWellAsStateThatWillNotDecode() throws {
    let file = scratchFile()
    let directory = file.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(#"{"projects":[{"path":"file:///repos/demo/"}]}"#.utf8).write(to: file)
    // Readable to nobody, as a restore from a backup under sudo leaves it.
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)

    var reported: URL?
    #expect(throws: (any Error).self) {
      do {
        _ = try WorkspaceFile(fileURL: file).load()
      } catch let state as UnreadableState {
        reported = state.backup
        throw state
      }
    }

    #expect(!FileManager.default.fileExists(atPath: file.path), "left where a save would land")
    #expect(FileManager.default.fileExists(atPath: reported?.path ?? ""), "the alert names it")
  }

  /// Moving it aside frees the path to write. Where that fails too the state
  /// is still there; see Docs/design/state-and-store.md.
  @Test @MainActor func aStateFileMovedAwayMidSessionLetsSavingResume() throws {
    let file = scratchFile()
    let directory = file.deletingLastPathComponent()
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(#"{"projects":[{"path":"file:///repos/demo/"}]}"#.utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: directory.path)
    let (store, _) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))
    #expect(store.refusesToSave)

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: directory.path)
    try FileManager.default.moveItem(at: file, to: directory.appendingPathComponent("kept.json"))
    store.addProject(at: URL(fileURLWithPath: "/repos/other"))
    try store.save()

    #expect(!store.refusesToSave)
    let saved = try WorkspaceFile(fileURL: file).load()
    #expect(saved.projects.map(\.path.path) == ["/repos/other"])
  }

  @Test @MainActor func aStateFileThatCannotBeMovedAsideIsNeverSavedOver() throws {
    let file = scratchFile()
    let directory = file.deletingLastPathComponent()
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let original = #"{"projects":[{"path":"file:///repos/demo/"}]}"#
    try Data(original.utf8).write(to: file)
    // Unreadable, and in a directory that takes no rename, so neither the
    // read nor the move aside can happen.
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: directory.path)

    let (store, loadError) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))

    #expect(loadError is UnmovedState)
    #expect(store.refusesToSave)
    #expect(store.workspace.projects.isEmpty, "it did start empty; that is the danger")
    store.addProject(at: URL(fileURLWithPath: "/repos/other"))
    #expect(throws: Never.self) { try store.save() }

    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
    #expect(
      try String(contentsOf: file, encoding: .utf8) == original,
      "the user's own state is still on disk, untouched")
  }

  @Test @MainActor func restoringRepairsDanglingReferencesBeforeTheStoreSeesThem() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

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
    try WorkspaceFile(fileURL: file).save(workspace)

    let (store, error) = WorkspaceStore.restored(from: WorkspaceFile(fileURL: file))

    #expect(error == nil)
    #expect(store.workspace.worktrees.map(\.id) == [worktree.id])
    #expect(
      store.workspace.sessions.isEmpty,
      "a session no tab shows would get a shell nobody can close")
  }

  /// Autosave encodes and writes on the main thread after every change. A
  /// workspace far larger than anyone keeps must still save in a blink.
  @Test func aLargeWorkspaceSavesAndLoadsQuickly() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    var workspace = Workspace()
    for p in 0..<20 {
      let project = Project(path: URL(fileURLWithPath: "/repos/p\(p)"))
      workspace.projects.append(project)
      for w in 0..<10 {
        let worktree = Worktree(
          path: URL(fileURLWithPath: "/repos/p\(p)-trees/w\(w)"), projectID: project.id,
          head: "abc", branch: "w\(w)")
        workspace.worktrees.append(worktree)
        var group = TabGroup(worktreeID: worktree.id)
        for _ in 0..<10 {
          let a = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "a")
          let b = TerminalSession(
            worktreeID: worktree.id, workingDirectory: worktree.path, title: "b")
          workspace.sessions += [a, b]
          workspace.tabs.append(
            TerminalTab(
              worktreeID: worktree.id, groupID: group.id,
              root: .split(axis: .horizontal, children: [.terminal(a.id), .terminal(b.id)]),
              focusedSessionID: a.id))
        }
        group.activeTabID = workspace.tabs.last?.id
        workspace.tabGroups.append(group)
        workspace.focusedGroupByWorktree[worktree.id] = group.id
      }
    }
    #expect(workspace.tabs.count == 2000)

    let stateFile = WorkspaceFile(fileURL: file)
    let saving = ContinuousClock.now
    try stateFile.save(workspace)
    let saved = ContinuousClock.now - saving
    let loading = ContinuousClock.now
    let loaded = try stateFile.load()
    let loadTime = ContinuousClock.now - loading

    #expect(loaded == workspace)
    // Locally each takes a few tens of ms; the bounds allow for a loaded two-core runner
    // and catch an accidental quadratic, which costs minutes, not a doubling.
    #expect(saved < .seconds(5), "save took \(saved)")
    #expect(loadTime < .seconds(5), "load took \(loadTime)")

    // Every launch repairs what it loaded, on the main thread, before the
    // window appears.
    var repaired = loaded
    let repairing = ContinuousClock.now
    repaired.repairReferences()
    let repairTime = ContinuousClock.now - repairing
    #expect(repaired == loaded, "a sound workspace is left alone")
    #expect(repairTime < .seconds(5), "repair took \(repairTime)")
  }

  @Test func roundTripPreservesEverything() throws {
    let file = scratchFile()
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    // Every scalar is off its default, so a field the decoder forgets fails here. The pairs
    // seeded from each other (auto-start, opens-terminal) differ, or a dropped key passes.
    var workspace = Workspace()
    workspace.projects = [
      Project(
        path: URL(fileURLWithPath: "/repos/demo"), settings: ProjectSettings(branchPrefix: "k/"))
    ]
    workspace.worktreeNames = ["/repos/demo": "trunk"]
    workspace.appearance.themeID = "multishell.light"
    workspace.appearance.fontName = "Menlo"
    workspace.appearance.fontSize = 15
    workspace.appearance.uiFontSize = 16
    workspace.worktreeDefaults = WorktreeSettings(
      worktreeDirectory: "/trees", branchPrefix: "team/")
    workspace.notifications = NotificationPreference(attention: true, done: true)
    workspace.preferredAgentID = "claude"
    workspace.customAgentCommand = "my-agent --flag"
    workspace.agentFlags = ["claude": "--model haiku"]
    workspace.autoStartAgent = true
    workspace.autoStartAgentOnCreate = false
    workspace.defaultShell = "/opt/homebrew/bin/fish"
    workspace.customShellPath = "/usr/local/bin/zsh"
    workspace.preferredEditorID = "vscode"
    workspace.customEditorCommand = "edit {path}"
    workspace.opensTerminalOnSelect = false
    workspace.opensTerminalOnCreate = true
    workspace.worktreeSortOrder = .committedNewestFirst
    workspace.showsActiveWorktreesFirst = true
    workspace.confirmsWorktreeRemoval = false
    workspace.deletesBranchWithWorktree = true
    workspace.trashesRemovedWorktrees = false
    workspace.hookTimeoutSeconds = 5
    workspace.gitStatusIndicator = .stagedOnly

    let stateFile = WorkspaceFile(fileURL: file)
    try stateFile.save(workspace)
    #expect(try stateFile.load() == workspace)
  }
}
