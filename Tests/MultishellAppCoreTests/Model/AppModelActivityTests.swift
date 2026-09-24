import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelActivityTests {
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

  @Test func aRetitleInAShellThatReportsFinishedCommandsSchedulesNoStatusRead() {
    let h = Harness()
    h.model.updateSettings(ProjectSettings(defaultShell: "/bin/zsh"), for: h.project)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "◐ claude")

    #expect(h.model.title(of: tab) == "◐ claude")
    #expect(h.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func aRetitleInFishSchedulesAStatusReadAsItsPromptIsTheOnlySign() {
    let h = Harness()
    h.model.updateSettings(ProjectSettings(defaultShell: "/opt/homebrew/bin/fish"), for: h.project)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "~/demo")

    #expect(h.model.pendingStatusRefreshes[h.main.id] != nil)
  }

  @Test func aRetitleInFishFromAnAgentsTabSchedulesNoStatusRead() {
    let h = Harness()
    h.model.updateSettings(ProjectSettings(defaultShell: "/opt/homebrew/bin/fish"), for: h.project)
    h.model.select(h.main)
    h.model.newAgentTab("claude")
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didRetitle: tab.focusedSessionID, to: "◐ claude")

    #expect(h.model.pendingStatusRefreshes.isEmpty)
  }

  @Test func activityOfAShellThatExitedIsForgotten() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.state(ofWorktree: h.main.id) == .done)

    h.engine.delegate?.terminalHost(h.engine, didExit: first.focusedSessionID)

    #expect(h.model.sessionStates.isEmpty, "nothing left to look at")
  }

  @Test func aProcessExitDropsTheTabAndTheLiveCount() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID)

    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
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

    h.engine.delegate?.terminalHost(h.engine, didExit: tab.focusedSessionID)
    #expect(h.model.sessionTitles.isEmpty, "titles of dead shells are not kept")
  }
}

@Suite @MainActor
struct AttentionDotTests {
  /// The dot means "something happened here since you looked", and the tab an
  /// exit reveals is being looked at, as if clicked.
  @Test func aTabRevealedByAnExitLosesItsDot() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!
    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(h.model.state(of: first) == .done)

    h.engine.delegate?.terminalHost(h.engine, didExit: second.focusedSessionID)

    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == first.id)
    #expect(h.model.state(of: first) == nil)
    #expect(h.model.state(ofWorktree: h.main.id) == nil)
  }
}
