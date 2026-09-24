import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// What a tab runs: the shell, an agent and its flags, an editor.
@Suite @MainActor
struct AppModelLaunchTests {
  @Test func eachTabRunsTheShellInForceForItsProject() {
    let h = Harness()
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Shell")
    #expect(h.model.prepared(session).shellPath == ShellCatalogue.loginShellPath())

    h.model.setDefaultShell("/bin/bash")
    #expect(h.model.prepared(session).shell == "/bin/bash")

    h.model.updateSettings(ProjectSettings(defaultShell: "/bin/sh"), for: h.project)
    #expect(h.model.prepared(session).shell == "/bin/sh", "the project's override wins")

    h.model.updateSettings(
      ProjectSettings(defaultShell: ShellCatalogue.loginShellID), for: h.project)
    #expect(
      h.model.prepared(session).shell == ShellCatalogue.loginShellPath(),
      "a project can step back to $SHELL under a global choice")

    h.model.select(h.main)
    #expect(h.engine.opened.last?.shell == ShellCatalogue.loginShellPath(), "reaches the engine")
    #expect(h.model.workspace.sessions.allSatisfy { $0.shell == nil }, "never in the workspace")
  }

  @Test func anAgentTabsFollowingShellIsTheChosenOne() {
    let h = Harness()
    h.model.setDefaultShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.customID)
    h.model.setCustomAgentCommand("my-agent")
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Agent",
      agentID: AgentCatalogue.customID)

    let prepared = h.model.prepared(session)

    #expect(prepared.command?.last == "my-agent; exec /bin/sh -l")
  }

  /// The flags are the user's, so they reach the command line whole, with
  /// `{{branch}}` standing for the tab's own worktree.
  @Test func anAgentTabCarriesTheFlagsWithItsPlaceholdersFilledIn() {
    let h = Harness()
    h.model.setDefaultShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.claudeID)
    h.model.agentDetection = AgentDetection(found: ["claude": URL(fileURLWithPath: "/bin/claude")])
    h.model.setAgentFlags("--name={{branch}} --model opus", for: AgentCatalogue.claudeID)
    let session = TerminalSession(
      worktreeID: h.feature.id, workingDirectory: h.feature.path, title: "Claude Code",
      agentID: AgentCatalogue.claudeID)

    #expect(
      h.model.prepared(session).command?.last
        == "claude '--name=feature' --model opus; exec /bin/sh -l"
    )

    h.model.updateSettings(ProjectSettings(agentFlags: "--model haiku"), for: h.project)
    #expect(
      h.model.prepared(session).command?.last == "claude --model haiku; exec /bin/sh -l",
      "the project's line replaces the global one")

    h.model.updateSettings(ProjectSettings(agentFlags: ""), for: h.project)
    #expect(
      h.model.prepared(session).command?.last == "claude; exec /bin/sh -l",
      "blank runs it bare under a global that passes flags")
  }

  /// A saved tab that comes back as `claude --continue` is the same tab,
  /// and the flags said how that tab is meant to run.
  @Test func aResumedAgentTabIsStartedWithTheFlagsToo() throws {
    let file = Scratch.path("agent-flags")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.setPreferredAgent(AgentCatalogue.claudeID)
    before.model.setAgentFlags("--name={{branch}}", for: AgentCatalogue.claudeID)
    before.model.select(before.main)
    before.store.openTab(in: before.main.id, title: "Claude Code", agentID: AgentCatalogue.claudeID)
    before.model.saveNow()

    let (store, _) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine, worktrees: nil,
      watcher: FakeWatcher())
    after.select(before.main)

    let opened = engine.opened.first { store.workspace.session($0.id)?.title == "Claude Code" }
    #expect(opened?.command?.last?.hasPrefix("claude --continue '--name=main'; ") == true)
  }

  @Test func aRenamedWorktreeAndACustomCommandTakePlaceholdersToo() {
    let h = Harness()
    h.model.setDefaultShell("/bin/sh")
    h.model.setPreferredAgent(AgentCatalogue.customID)
    h.model.setCustomAgentCommand("my-agent --name={{worktree}}")
    h.model.renameWorktree(h.feature.id, to: "The fix")
    let session = TerminalSession(
      worktreeID: h.feature.id, workingDirectory: h.feature.path, title: "Agent",
      agentID: AgentCatalogue.customID)

    let command = h.model.prepared(session).command
    #expect(command?.last == #"my-agent --name="$MULTISHELL_WORKTREE_NAME"; exec /bin/sh -l"#)
    #expect(
      command?.prefix(2) == ["/usr/bin/env", "MULTISHELL_WORKTREE_NAME=The fix"],
      "the value is handed over around the shell, never written into its line")
  }

  @Test func theCustomShellPathReachesTabsAndTheCaptionSaysWhenItWillNot() {
    let h = Harness()
    let session = TerminalSession(
      worktreeID: h.main.id, workingDirectory: h.main.path, title: "Shell")
    h.model.setDefaultShell(ShellCatalogue.customID)
    #expect(h.model.prepared(session).shell == ShellCatalogue.loginShellPath(), "blank path")
    #expect(h.model.customShellPathProblem?.hasPrefix("Blank") == true)
    #expect(h.model.shellDisplayName(ShellCatalogue.customID).contains("blank"))

    h.model.setCustomShellPath("/no/such/shell")
    #expect(h.model.prepared(session).shell == "/no/such/shell")
    #expect(h.model.customShellPathProblem?.hasPrefix("Nothing executable") == true)

    h.model.setCustomShellPath(" /bin/sh ")
    #expect(h.model.prepared(session).shell == "/bin/sh")
    #expect(h.model.customShellPathProblem == nil)
    #expect(h.model.shellDisplayName(ShellCatalogue.customID) == "the custom path /bin/sh")
    h.model.updateSettings(ProjectSettings(defaultShell: "/bin/bash"), for: h.project)
    #expect(h.model.prepared(session).shell == "/bin/bash", "a project override still wins")
  }

  /// Nothing that acts on the tab in front of the user acts at all while the
  /// board covers it, and nothing starts a shell where a removal is running.
  @Test func openInEditorLeavesTheBoardAndRefusesABusyWorktree() throws {
    let h = Harness()
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.showAgentBoard()
    #expect(h.model.showsAgentBoard)

    h.model.openInEditor(h.main)

    #expect(!h.model.showsAgentBoard, "a tab opened behind the board nobody can see or close")
    #expect(h.model.workspace.activeTab(in: h.main.id) != nil)

    let busy = Harness()
    busy.model.setPreferredEditor(EditorCatalogue.customID)
    busy.model.setCustomEditorCommand("my-editor {path}")
    busy.model.worktreeOperations.begin(.preDeleteHook, on: busy.main.id)
    busy.model.presentedError = nil

    busy.model.openInEditor(busy.main)

    #expect(busy.model.workspace.tabs.isEmpty, "its directory is about to be trashed")
  }

  @Test func anEditorsShimRunsUnderTheProjectsShell() async throws {
    let h = Harness()
    let shells = h.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let ran = h.root.appendingPathComponent("shell-ran")
    let shell = try Scratch.script(
      "echo \"$@\" > '\(ran.path)'", at: shells.appendingPathComponent("bash"))
    let code = try Scratch.script("exit 0", at: shells.appendingPathComponent("code"))
    h.model.editorDetection = EditorDetection(
      found: ["vscode": .init(application: nil, command: code)])
    h.model.setPreferredEditor("vscode")
    h.model.updateSettings(ProjectSettings(defaultShell: shell.path), for: h.project)

    h.model.openInEditor(h.main)

    try await waitUntil { FileManager.default.fileExists(atPath: ran.path) }
    #expect(try String(contentsOf: ran, encoding: .utf8).contains(code.path))
  }

  @Test func openInEditorFromTheMenuOverTheBoardOpensNothing() {
    let h = Harness()
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.select(h.main)
    let opened = h.engine.opened.count
    h.model.showAgentBoard()

    h.model.openSelectedWorktreeInEditor()

    #expect(h.engine.opened.count == opened, "no worktree is on screen to open")
    #expect(h.model.showsAgentBoard)
  }

  @Test func openInEditorNeedsAnEditorAndACustomOneBecomesATab() throws {
    let h = Harness()
    h.model.presentedError = nil
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "No editor chosen")
    #expect(h.model.workspace.tabs.isEmpty)

    h.model.presentedError = nil
    h.model.setPreferredEditor(EditorCatalogue.customID)
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "No editor command", "nothing typed yet")

    h.model.presentedError = nil
    h.model.setCustomEditorCommand("my-editor {path}")
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError == nil)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(h.model.workspace.title(of: tab) == "my-editor")
    #expect(h.model.workspace.selectedWorktreeID == h.main.id, "the tab is brought on screen")
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.opened.last?.command?.last?.hasPrefix("my-editor ") == true)
    #expect(
      h.engine.opened.last?.command?.contains("MULTISHELL_WORKTREE_PATH=\(h.main.path.path)")
        == true)

    h.model.setPreferredEditor("vscode")
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "Visual Studio Code is not installed")
  }
}
