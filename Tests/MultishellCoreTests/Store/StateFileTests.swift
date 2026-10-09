import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct StateFileTests {
  @Test func stateWrittenBeforeAFieldExistedStillLoads() throws {
    // Only what the very first build wrote: no appearance, no engine, no tabs.
    let file = try scratchStateFile(
      holding:
        #"{ "projects": [ { "path": "file:///repos/demo/" } ], "worktrees": [], "sessions": [] }"#
    )
    defer { Scratch.remove(file.deletingLastPathComponent()) }

    let workspace = try StateFile(fileURL: file).load()

    #expect(workspace.projects.map(\.name) == ["demo"])
    #expect(workspace.appearance.themeID == Theme.multishellDark.id)
  }

  @Test func unreadableStateIsMovedAsideNotOverwritten() throws {
    let file = try scratchStateFile(holding: "not json")
    let directory = file.deletingLastPathComponent()
    defer { Scratch.remove(directory) }

    let stateFile = StateFile(fileURL: file)
    var reported: URL?
    do {
      _ = try stateFile.load()
      Issue.record("unreadable state loaded")
    } catch let state as UnreadableStateFile {
      reported = state.backup
    }

    let survivors = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(survivors.contains { $0.hasSuffix(".broken.json") })
    #expect(
      FileManager.default.fileExists(atPath: reported?.path ?? ""),
      "the alert names the backup, so it must be the file that was written",
    )
    #expect(
      try String(contentsOf: directory.appendingPathComponent(survivors[0]), encoding: .utf8)
        == "not json"
    )
  }

  /// The decode path moved a file aside and the read path did not, so one
  /// that would not open was left where an empty workspace would be saved.
  @Test func stateThatWillNotOpenIsMovedAsideAsWellAsStateThatWillNotDecode() throws {
    let file = try scratchStateFile(holding: #"{"projects":[{"path":"file:///repos/demo/"}]}"#)
    let directory = file.deletingLastPathComponent()
    defer { Scratch.remove(directory) }
    // Readable to nobody, as a restore from a backup under sudo leaves it.
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)

    var reported: URL?
    #expect(throws: (any Error).self) {
      do {
        _ = try StateFile(fileURL: file).load()
      } catch let state as UnreadableStateFile {
        reported = state.backup
        throw state
      }
    }

    #expect(!FileManager.default.fileExists(atPath: file.path), "left where a save would land")
    #expect(FileManager.default.fileExists(atPath: reported?.path ?? ""), "the alert names it")
  }

  /// Autosave encodes and writes on the main thread after every change. A
  /// workspace far larger than anyone keeps must still save in a blink.
  @Test func aLargeWorkspaceSavesLoadsAndRepairsWithoutAQuadratic() throws {
    let file = Scratch.statePath()
    defer { Scratch.remove(file.deletingLastPathComponent()) }
    var workspace = Workspace()
    for projectNumber in 0..<20 {
      let project = Project(path: URL(fileURLWithPath: "/repos/p\(projectNumber)"))
      workspace.projects.append(project)
      for worktreeNumber in 0..<10 {
        let worktree = Worktree(
          path: URL(fileURLWithPath: "/repos/p\(projectNumber)-trees/w\(worktreeNumber)"),
          projectID: project.id,
          head: "abc",
          branch: "w\(worktreeNumber)",
        )
        workspace.worktrees.append(worktree)
        var group = TabGroup(worktreeID: worktree.id)
        for _ in 0..<10 {
          let a = TerminalSession(
            worktreeID: worktree.id,
            workingDirectory: worktree.path,
            title: "a",
          )
          let b = TerminalSession(
            worktreeID: worktree.id,
            workingDirectory: worktree.path,
            title: "b",
          )
          workspace.sessions += [a, b]
          workspace.tabs.append(
            TerminalTab(
              worktreeID: worktree.id,
              groupID: group.id,
              root: .split(axis: .horizontal, children: [.terminal(a.id), .terminal(b.id)]),
              focusedSessionID: a.id,
            )
          )
        }
        group.shownTabID = workspace.tabs.last?.id
        workspace.tabGroups.append(group)
        workspace.focusedGroupByWorktree[worktree.id] = group.id
      }
    }
    #expect(workspace.tabs.count == 2000)

    let stateFile = StateFile(fileURL: file)
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
    repaired.repair()
    let repairTime = ContinuousClock.now - repairing
    #expect(repaired == loaded, "a consistent workspace is left alone")
    #expect(repairTime < .seconds(5), "repair took \(repairTime)")
  }

  @Test func everySavedFieldLoadsBackAsItWasSaved() throws {
    let file = Scratch.statePath()
    defer { Scratch.remove(file.deletingLastPathComponent()) }

    // Every scalar is off its default, so a field the decoder forgets fails here. The pairs
    // seeded from each other (auto-start, opens-terminal) differ, or a dropped key passes.
    var workspace = Workspace()
    workspace.projects = [
      Project(
        path: URL(fileURLWithPath: "/repos/demo"),
        settings: ProjectSettings(branchPrefix: "k/"),
      )
    ]
    workspace.customWorktreeNames = ["/repos/demo": "trunk"]
    workspace.appearance.themeID = "multishell.light"
    workspace.appearance.terminalFontName = "Menlo"
    workspace.appearance.terminalFontSize = 15
    workspace.appearance.uiFontSize = 16
    workspace.worktreeDefaults = WorktreeSettings(
      worktreeDirectory: "/trees",
      branchPrefix: "team/",
    )
    workspace.notificationPreference = NotificationPreference(
      notifiesOnAttention: true,
      notifiesOnDone: true,
    )
    workspace.preferredAgentID = "claude"
    workspace.customAgentCommand = "my-agent --flag"
    workspace.agentFlags = ["claude": "--model haiku"]
    workspace.autoStartsAgent = true
    workspace.autoStartsAgentOnCreate = false
    workspace.preferredShellID = "/opt/homebrew/bin/fish"
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
    workspace.projectHookTimeoutSeconds = 5
    workspace.gitStatusIndicator = .stagedOnly

    let stateFile = StateFile(fileURL: file)
    try stateFile.save(workspace)
    #expect(try stateFile.load() == workspace)
  }
}
