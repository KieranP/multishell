import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTerminalEventsTests {
  @Test func activityInABackgroundTabIsRememberedUntilItIsShown() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: first.focusedSessionID)
    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: second.focusedSessionID)

    #expect(harness.model.state(of: first) == .done)
    #expect(harness.model.state(of: second) == nil, "the focused tab is being watched")
    #expect(harness.model.state(ofWorktree: harness.main.id) == .done)

    harness.model.activate(first)
    #expect(harness.model.state(of: first) == nil)
  }

  @Test func aBurstOfActivityCoalescesIntoOneStatusRefresh() async {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    // Title before the command, command finished, title after: what one
    // prompt produces. Each used to spawn its own `git status`.
    for _ in 0..<3 {
      harness.engine.delegate?.terminalHost(
        harness.engine, didRetitle: tab.focusedSessionID, to: "make")
      harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: tab.focusedSessionID)
    }

    #expect(harness.model.pendingStatusRefreshes.count == 1)
    #expect(harness.model.pendingStatusRefreshes[harness.main.id] != nil)

    // The debounce is 250 ms; polled with headroom for a busy CI runner.
    try? await waitUntil { harness.model.pendingStatusRefreshes.isEmpty }
    #expect(harness.model.pendingStatusRefreshes.isEmpty, "the one refresh ran and cleared itself")
  }

  @Test func aRetitleInAShellThatReportsFinishedCommandsSchedulesNoStatusRead() {
    let harness = Harness()
    harness.model.setSettings(ProjectSettings(preferredShellID: "/bin/zsh"), for: harness.project)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(
      harness.engine, didRetitle: tab.focusedSessionID, to: "◐ claude")

    #expect(harness.model.title(of: tab) == "◐ claude")
    #expect(harness.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func aRetitleInFishSchedulesAStatusReadAsItsPromptIsTheOnlySign() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(preferredShellID: "/opt/homebrew/bin/fish"), for: harness.project)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(
      harness.engine, didRetitle: tab.focusedSessionID, to: "~/demo")

    #expect(harness.model.pendingStatusRefreshes[harness.main.id] != nil)
  }

  @Test func aRetitleInFishFromAnAgentsTabSchedulesNoStatusRead() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(preferredShellID: "/opt/homebrew/bin/fish"), for: harness.project)
    harness.model.select(harness.main)
    harness.model.newAgentTab("claude")
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(
      harness.engine, didRetitle: tab.focusedSessionID, to: "◐ claude")

    #expect(harness.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func activityOfAShellThatExitedIsForgotten() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(harness.model.state(ofWorktree: harness.main.id) == .done)

    harness.engine.delegate?.terminalHost(harness.engine, didExit: first.focusedSessionID)

    #expect(harness.model.sessionStates.showsNothing, "nothing left to look at")
  }

  @Test func aProcessExitDropsTheTabAndTheLiveCount() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(harness.engine, didExit: tab.focusedSessionID)

    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func shellTitlesAreShownButNeverWrittenToTheWorkspace() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let before = harness.model.workspace

    harness.engine.delegate?.terminalHost(
      harness.engine, didRetitle: tab.focusedSessionID, to: "vim")
    #expect(harness.model.title(of: tab) == "vim")
    #expect(harness.model.workspace == before, "a prompt must not trigger a save")

    harness.model.renameTab(tab.id, to: "build")
    #expect(harness.model.title(of: harness.model.workspace.tab(tab.id)!) == "build")
    harness.model.renameTab(tab.id, to: nil)
    #expect(harness.model.title(of: harness.model.workspace.tab(tab.id)!) == "vim")

    harness.engine.delegate?.terminalHost(harness.engine, didExit: tab.focusedSessionID)
    #expect(harness.model.sessionTitles.isEmpty, "titles of dead shells are not kept")
  }

  @Test func aFinishedCommandClearsWorkingAndAFailedOneOutlastsALook() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: first.focusedSessionID, pid: 1))

    harness.engine.delegate?.terminalHost(
      harness.engine, didRetitle: first.focusedSessionID, to: "claude")
    #expect(harness.model.state(of: first) == .running, "a title change is not evidence of an exit")

    harness.engine.delegate?.terminalHost(
      harness.engine, didFinishCommandIn: first.focusedSessionID, exitCode: 0)
    #expect(harness.model.state(of: first) == .done)
    #expect(harness.model.sessionStates.trackedPIDs.isEmpty)

    harness.engine.delegate?.terminalHost(
      harness.engine, didFinishCommandIn: first.focusedSessionID, exitCode: 1)
    #expect(harness.model.state(of: first) == .failed, "a failure is not covered by an unseen Done")
    #expect(harness.model.state(ofWorktree: harness.main.id) == .failed)
    harness.model.activate(first)
    #expect(harness.model.state(of: first) == .failed, "a look is not dealing with a failure")
    harness.model.clearState(of: first)
    #expect(harness.model.state(of: first) == nil, "the pane's own Clear Status is")
  }
}
