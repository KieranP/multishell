import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelWorktreesTests {
  @Test func selectingAWorktreeOpensATabAndWarmsIt() {
    let h = Harness()
    h.model.select(h.main)

    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.model.liveTerminalCount == 1)
    #expect(h.engine.focused.count == 1)
    #expect(h.model.liveSessionIDs == h.engine.openSessionIDs)
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

  @Test func selectingAWorktreeOnAVolumeThatDoesNotAnswerIsRefusedWithoutWaitingForIt() {
    let h = Harness()
    let stat = HangingStat()
    defer { stat.release() }
    h.model.directoryProbe = DirectoryProbe(bound: .milliseconds(50), exists: stat.exists)
    h.model.presentedError = nil

    h.model.select(h.feature)
    h.model.select(h.feature)

    #expect(!stat.hasReturned)
    #expect(stat.calls == 1, "a second stat would pile another thread onto the mount")
    #expect(h.model.workspace.selectedWorktreeID == nil)
    #expect(h.model.presentedError?.title == PresentedError.worktreeDirectoryUnanswered("").title)
    #expect(h.model.liveTerminalCount == 0)
  }
}
