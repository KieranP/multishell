import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Everything the model wants from the desktop goes through the port, so a
/// second frontend implements one protocol and the model is untouched.
@Suite @MainActor
struct AppModelPlatformTests {
  @Test func revealingAndCopyingGoThroughThePlatform() {
    let h = Harness()
    h.model.revealInFileBrowser(h.main.path)
    h.model.copyToClipboard("feature")
    #expect(h.platform.revealed == [h.main.path])
    #expect(h.platform.clipboard == ["feature"])
  }

  @Test func closingInAnotherWindowClosesThatWindowNotAPane() {
    let h = Harness()
    h.model.select(h.main)
    h.platform.workspaceWindowIsKey = false

    h.model.closeActivePane()
    h.model.closeActiveTab()

    #expect(h.platform.closedKeyWindows == 2)
    #expect(h.model.liveTerminalCount == 1, "the pane is still there")
  }

  @Test func aCancelledDirectoryPickerAddsNothing() async {
    let h = Harness()
    h.platform.directoryToChoose = nil
    await h.model.chooseProject()
    #expect(h.model.workspace.projects.count == 1)
  }

  @Test func theModelListensForTheAppComingToTheFrontAndCapturesTheLoginShell() async {
    let h = Harness()
    #expect(h.platform.onDidBecomeActive != nil, "the model listens from its init")
    await h.model.refreshLoginEnvironment()
    let environment = h.model.loginEnvironment
    #expect(environment != nil)
    if case .processFallback = environment?.source {
      #expect(h.platform.logged.count == 1, "a shell that could not answer is logged, not shown")
    } else {
      #expect(h.platform.logged.isEmpty)
    }
  }
}

@Suite @MainActor
struct AppModelTests {
  @Test func launchStartsWithNothingSelectedAndNoShells() {
    let h = Harness(savedSelection: true)
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.liveTerminalCount == 0)
    #expect(
      h.model.presentedError?.title == "git not found", "no git was injected, and that is reported")
  }

  @Test func selectingAWorktreeOpensATabAndWarmsIt() {
    let h = Harness()
    h.model.select(h.main)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.focused.count == 1)
    #expect(h.model.liveSessions == h.engine.openSessionIDs)
  }

  @Test func selectingOpensNoTerminalWhenTheSettingIsOff() {
    let h = Harness()
    h.model.setOpensTerminalOnSelect(false)

    h.model.select(h.main)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id, "shown, but empty")
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)

    h.model.newTab()
    #expect(h.model.liveTerminalCount == 1, "the + and Cmd+T still start one")

    h.store.openTab(in: h.feature.id)
    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 2, "saved tabs still warm up on a visit")
  }

  @Test func theActionsMenuOpensOneTabInTheWorktreeItWasAskedFor() {
    // What the menu does: select without the first tab, then its own tab.
    let h = Harness()
    h.model.select(h.main)
    #expect(h.model.select(h.feature, openingFirstTab: .never))
    h.model.newShellTab()

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1, "not a first tab and then another")
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
  }

  @Test func withOpenOnSelectOffAWorktreeIsShownEmptyUntilATabIsAskedFor() {
    let h = Harness()
    h.model.setOpensTerminalOnSelect(false)

    h.model.select(h.main)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty, "looked at, not started")

    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "a tab asked for still opens")
  }

  @Test func turningToAWorktreeStartsTheAgentWhereAutoStartOnTabOpenIsOn() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)

    h.model.select(h.main)

    let tab = h.model.workspace.activeTab(in: h.main.id)
    #expect(h.model.workspace.session(tab!.focusedSessionID)?.agentID == "claude")
  }

  @Test func selectingAMissingWorktreeSaysSoInsteadOfActingOnTheSelectedOne() throws {
    let h = Harness()
    h.model.select(h.main)
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: h.project.id,
      head: "c", branch: "ghost")
    h.store.replaceWorktrees([h.main, h.feature, ghost], forProject: h.project.id)

    #expect(!h.model.select(ghost, openingFirstTab: .never), "the menu must not open a tab in main")
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
  }

  @Test func removingAProjectAsksFirstInTheWindowThatAsked() throws {
    let h = Harness()
    h.model.select(h.main)
    #expect(h.model.liveTerminalCount == 1)

    h.model.requestProjectRemoval(h.project, from: .settings)

    let pending = try #require(h.model.pendingProjectRemoval)
    #expect(pending.project.id == h.project.id)
    #expect(pending.source == .settings)
    #expect(h.model.workspace.projects.count == 1, "nothing removed until confirmed")
    #expect(
      h.model.projectRemovalMessage(for: h.project).contains("1 open terminal will be closed"))

    h.model.pendingProjectRemoval = nil
    h.model.removeProject(h.project)
    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

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
    #expect(h.engine.opened.last?.command?.last?.contains(h.main.path.lastPathComponent) == true)

    h.model.setPreferredEditor("vscode")
    h.model.openInEditor(h.main)
    #expect(h.model.presentedError?.title == "Visual Studio Code is not installed")
  }

  @Test func savedTabsInAnUnvisitedWorktreeStayCold() {
    let h = Harness()
    h.store.openTab(in: h.feature.id)
    h.store.openTab(in: h.feature.id)
    h.model.select(h.main)

    #expect(h.model.workspace.sessions.count == 3)
    #expect(h.model.liveTerminalCount == 1, "only the selected worktree's shell is live")

    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 3, "visiting warms the saved tabs, and main stays warm")
  }

  @Test func selectingAWorktreeWhoseDirectoryIsGoneIsRefused() {
    let h = Harness()
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: h.project.id,
      head: "c", branch: "ghost")
    h.store.replaceWorktrees([h.main, h.feature, ghost], forProject: h.project.id)
    h.model.presentedError = nil

    h.model.select(ghost)

    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func closingTheLastPaneClosesItsTabAndShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 2)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.engine.closed.count == 1)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)

    h.model.closeActivePane()  // nothing left: must not throw or select anything
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }

  @Test func splitThenCloseCollapsesBackToOnePane() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.isSplit && h.model.liveTerminalCount == 2)

    h.model.closeActivePane()
    let after = h.model.workspace.tab(tab.id)!
    #expect(!after.isSplit)
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func removalAsksUnlessTheGlobalSettingsSettleBothTheWorktreeAndTheBranch() {
    let h = Harness()
    h.model.requestRemoval(of: h.feature)
    #expect(h.model.pendingRemoval?.id == h.feature.id)
    #expect(h.model.pendingRemoval?.choices.count == 2)

    h.model.pendingRemoval = nil
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.requestRemoval(of: h.feature)
    #expect(h.model.pendingRemoval?.id == h.feature.id, "the branch question is still open")
    #expect(h.model.pendingRemoval?.choices.count == 2)

    h.model.pendingRemoval = nil
    h.model.setDeletesBranchWithWorktree(true)
    h.model.requestRemoval(of: h.feature)
    #expect(
      h.model.pendingRemoval == nil, "goes straight to removal, which needs git and so no-ops here")

    h.model.setConfirmsWorktreeRemoval(true)
    h.model.requestRemoval(of: h.feature)
    #expect(h.model.pendingRemoval?.deletesBranch == true)
    #expect(h.model.pendingRemoval?.choices.count == 1)
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

  @Test func activityInABackgroundTabIsRememberedUntilItIsShown() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: second.focusedSessionID)

    #expect(h.model.state(of: first) == .done)
    #expect(h.model.state(of: second) == nil, "the focused tab is being watched")
    #expect(h.model.state(ofWorktree: h.main.id) == .done)

    h.model.activate(first)
    #expect(h.model.state(of: first) == nil)
  }

  @Test func aBurstOfActivityCoalescesIntoOneStatusRefresh() async {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    // Title before the command, command finished, title after: what one
    // prompt produces. Each used to spawn its own `git status`.
    for _ in 0..<3 {
      h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "make")
      h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: tab.focusedSessionID)
    }

    #expect(h.model.pendingStatusRefreshes.count == 1)
    #expect(h.model.pendingStatusRefreshes[h.main.id] != nil)

    // The debounce is 250 ms; polled with headroom for a busy CI runner.
    for _ in 0..<160 where !h.model.pendingStatusRefreshes.isEmpty {
      try? await Task.sleep(for: .milliseconds(50))
    }
    #expect(h.model.pendingStatusRefreshes.isEmpty, "the one refresh ran and cleared itself")
  }

  @Test func activityOfAShellThatExitedIsForgotten() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.state(ofWorktree: h.main.id) == .done)

    h.engine.delegate?.terminalHost(h.engine, didExit: first.focusedSessionID, code: 0)

    #expect(h.model.sessionStates.isEmpty, "nothing left to look at")
  }

  @Test func aProcessExitDropsTheTabAndTheLiveCount() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID, code: 0)

    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func switchingEngineAffectsOnlyNewTabs() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setTerminalEngine(.swiftTerm)
    #expect(h.model.workspace.terminalEngine == .swiftTerm)
    #expect(h.model.host.engine == .swiftTerm)
    #expect(h.model.liveTerminalCount == 1, "the running shell was not restarted")
  }

  @Test func activeProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(h.model.activeProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.activeProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.activeProject?.id == h.project.id)
  }

  @Test func shellTitlesAreShownButNeverWrittenToTheWorkspace() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let before = h.model.workspace

    h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "vim")
    #expect(h.model.title(of: tab) == "vim")
    #expect(h.model.workspace == before, "a prompt must not trigger a save")

    h.model.renameTab(tab.id, to: "build")
    #expect(h.model.title(of: h.model.workspace.tab(tab.id)!) == "build")
    h.model.renameTab(tab.id, to: nil)
    #expect(h.model.title(of: h.model.workspace.tab(tab.id)!) == "vim")

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID, code: 0)
    #expect(h.model.sessionTitles.isEmpty, "titles of dead shells are not kept")
  }

  @Test func aFailingSaveIsReportedOnceNotAfterEveryChange() {
    // A file where a directory is needed: nothing can be created under it.
    let h = Harness(stateFile: URL(fileURLWithPath: "/dev/null/multishell/state.json"))
    h.model.presentedError = nil

    h.model.save()
    let first = h.model.presentedError
    #expect(first != nil)

    h.model.save()
    h.model.save()
    #expect(h.model.presentedError?.id == first?.id, "the same alert, not a new one each time")
  }

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, .before, a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])

    h.model.moveTab(b.id, .after, a.id)
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [a.id, b.id])
  }

  /// A middle click closes the tab it landed on, which need not be the
  /// active one; the keystrokes only ever close what is on screen.
  @Test func aMiddleClickClosesTheTabItLandedOnActiveOrNot() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!

    h.model.closeTab(first.id)

    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [second.id])
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == second.id, "the active one stays")
    #expect(h.engine.closed == [first.focusedSessionID], "its shell went with it")

    h.model.closeTab(UUID())
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "no such tab")
  }

  /// The same question Cmd+Shift+W asks, since a middle click on the wrong
  /// tab is at least as easy to make.
  @Test func aMiddleClickOnAWorkingAgentAsksFirst() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let working = h.model.workspace.activeTab(in: h.main.id)!
    h.model.select(h.feature)
    h.source.send(
      SessionStateReport(state: .running, sessionID: working.focusedSessionID, cwd: nil, pid: nil))

    h.model.closeTab(working.id)

    #expect(h.model.pendingClose == .tab(working.id))
    #expect(h.model.workspace.tab(working.id) != nil, "nothing closed until it is confirmed")

    h.model.confirmPendingClose()
    #expect(h.model.workspace.tab(working.id) == nil)
  }

  /// Dragged from the strip onto another worktree's row. The shells come
  /// with it and keep running, and the worktree it landed in is the one on
  /// screen, so the tab is where the drag left it.
  @Test func aTabDraggedOntoAnotherWorktreeGoesThereWithItsShells() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.splitActivePane(.vertical)
    let panes = Set(h.model.workspace.tab(tab.id)!.sessionIDs)

    #expect(h.model.moveTab(tab.id, to: h.feature.id))

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(panes.isSubset(of: h.engine.openSessionIDs), "the shells kept running")
    #expect(h.engine.closed.isEmpty)
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1, "no second tab was opened")
  }

  @Test func aTabIsNotDraggedIntoAWorktreeThatCannotTakeIt() {
    let h = Harness()
    let gone = Worktree(
      path: URL(fileURLWithPath: "/repos/gone"), projectID: h.project.id, head: "c",
      branch: "gone")
    h.store.replaceWorktrees([h.main, h.feature, gone], forProject: h.project.id)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.model.worktreeOperations.begin(.removingWorktree, on: h.feature.id)
    #expect(h.model.moveTab(tab.id, to: h.feature.id) == false, "a worktree on its way out")
    h.model.worktreeOperations.clear(h.feature.id)

    // The other end of the same rule: a tab dragged clear of a removal
    // would be the one thing still running in a trashed directory.
    h.model.worktreeOperations.begin(.removingWorktree, on: h.main.id)
    #expect(h.model.moveTab(tab.id, to: h.feature.id) == false, "dragged out of a removal")
    h.model.worktreeOperations.clear(h.main.id)

    h.model.presentedError = nil
    #expect(h.model.moveTab(tab.id, to: gone.id) == false)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.moveTab(tab.id, to: h.main.id) == false, "already there")

    #expect(h.model.workspace.tab(tab.id)?.worktreeID == h.main.id)
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }
}

@Suite @MainActor
struct AttentionDotTests {
  /// The dot means "something happened here since you looked". When the
  /// shown tab's shell exits, the neighbour becomes the shown tab and is
  /// being looked at, so its dot must go the way a click would clear it.
  @Test func aTabRevealedByAnExitLosesItsDot() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.state(of: first) == .done)

    h.engine.delegate?.terminalHost(h.engine, didExit: second.focusedSessionID, code: 0)

    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == first.id)
    #expect(h.model.state(of: first) == nil)
    #expect(h.model.state(ofWorktree: h.main.id) == nil)
  }
}

@Suite @MainActor
struct MissingDirectoryTests {
  /// Selection was refused when the directory was gone, but a worktree that
  /// was selected while it existed could still get new shells after it was
  /// deleted by hand, each landing silently in $HOME.
  @Test func aNewTabOrSplitInAWorktreeWhoseDirectoryVanishedIsRefused() throws {
    let h = Harness()
    h.model.select(h.feature)
    #expect(h.model.liveTerminalCount == 1)
    try FileManager.default.removeItem(at: h.feature.path)
    h.model.presentedError = nil

    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")

    h.model.presentedError = nil
    h.model.splitActivePane(.horizontal)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.isSplit == false)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.liveTerminalCount == 1, "the shell that already existed is left alone")
  }
}

/// What the New Worktree sheet opens with, from each way of asking for it.
@Suite @MainActor
struct NewWorktreeRequestTests {
  @Test func theMenuWithOneProjectAndNothingSelectedPicksThatProject() {
    let h = Harness()
    h.model.requestNewWorktree()
    #expect(h.model.newWorktreeRequest?.projectID == h.project.id)
  }

  @Test func theMenuWithSeveralProjectsAndNothingSelectedOpensWithNoProject() {
    let h = Harness()
    h.store.addProject(at: URL(fileURLWithPath: "/other"))

    h.model.requestNewWorktree()

    #expect(h.model.newWorktreeRequest != nil, "used to do nothing, silently")
    #expect(h.model.newWorktreeRequest?.projectID == nil, "the picker starts blank")
  }

  @Test func theMenuFollowsTheSelectedWorktreesProject() {
    let h = Harness()
    let other = h.store.addProject(at: URL(fileURLWithPath: "/other"))
    h.model.select(h.feature)

    h.model.requestNewWorktree()

    #expect(h.model.newWorktreeRequest?.projectID == h.project.id)
    #expect(h.model.newWorktreeRequest?.projectID != other.id)
  }

  @Test func theSidebarNamesItsProjectWhateverIsSelected() {
    let h = Harness()
    let other = h.store.addProject(at: URL(fileURLWithPath: "/other"))
    h.model.select(h.main)

    h.model.requestNewWorktree(in: other)

    #expect(h.model.newWorktreeRequest?.projectID == other.id)
  }

  @Test func eachRequestIsANewPresentation() {
    let h = Harness()
    h.model.requestNewWorktree()
    let first = h.model.newWorktreeRequest?.id
    h.model.newWorktreeRequest = nil
    h.model.requestNewWorktree()
    #expect(h.model.newWorktreeRequest?.id != first, "the sheet must reopen after a cancel")
  }
}

/// The whole promise of saving: quit, relaunch, and what was there is there.
/// Tabs, splits, weights and names come back; nothing is live until a
/// worktree is visited; the first visit brings every saved shell up.
@Suite(.serialized) @MainActor
struct RelaunchTests {
  @Test func aSavedWorkspaceComesBackAndWarmsOnTheFirstVisit() throws {
    let file = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-relaunch-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.model.splitActivePane(.horizontal)
    let splitTab = before.model.workspace.activeTab(in: before.main.id)!
    before.model.setSplitWeights([3, 1], at: [], ofTab: splitTab.id)
    before.model.newTab()
    before.model.renameTab(before.model.workspace.activeTab(in: before.main.id)!.id, to: "build")
    before.model.select(before.feature)
    before.model.newTab()
    #expect(before.model.liveTerminalCount == 5, "two in the split, one more, then two in feature")
    before.model.saveNow()
    var expected = before.model.workspace
    expected.selectedWorktreeID = nil

    let (store, error) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    #expect(error == nil)
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: MultiEngineHost(engine: .ghostty) { _ in engine },
      worktrees: nil, watcher: FakeWatcher())

    #expect(after.workspace == expected, "everything but the selection, which a launch clears")
    #expect(after.liveTerminalCount == 0, "nothing starts until a worktree is visited")

    after.select(before.main)
    #expect(after.liveTerminalCount == 3, "both tabs of main, one of them split")
    let tabs = after.workspace.tabs(in: before.main.id)
    #expect(tabs.map(\.isSplit) == [true, false])
    #expect(after.title(of: tabs[1]) == "build")
    guard case .split(.horizontal, _, let weights) = tabs[0].root else {
      Issue.record("the split did not come back")
      return
    }
    #expect(weights == [3, 1])
    #expect(after.workspace.activeTab(in: before.main.id)?.id == tabs[1].id)
    #expect(engine.openSessionIDs == Set(after.workspace.sessions(in: before.main.id).map(\.id)))

    after.select(before.feature)
    #expect(after.liveTerminalCount == 5)
  }
}

@Suite @MainActor
struct NullPlatformTests {
  @Test func withoutATrashARemovedDirectoryIsDeleted() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-null-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try "x".write(to: directory.appendingPathComponent("f"), atomically: true, encoding: .utf8)

    try NullPlatform().moveToTrash(directory)

    #expect(!FileManager.default.fileExists(atPath: directory.path))
  }
}
