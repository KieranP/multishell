import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelWorktreesTests {
  @Test func selectingAWorktreeOpensATabAndWarmsIt() {
    let harness = Harness()
    harness.model.select(harness.main)

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1)
    #expect(harness.model.liveTerminalCount == 1)
    #expect(harness.engine.focused.count == 1)
    #expect(harness.model.liveSessionIDs == harness.engine.liveSessionIDs)
  }

  @Test func selectingOpensNoTerminalWhenTheSettingIsOff() {
    let harness = Harness()
    harness.model.setOpensTerminalOnSelect(false)

    harness.model.select(harness.main)

    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id, "shown, but empty")
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(harness.model.liveTerminalCount == 0)

    harness.model.newTab()
    #expect(harness.model.liveTerminalCount == 1, "the + and Cmd+T still start one")

    harness.store.openTab(in: harness.feature.id)
    harness.model.select(harness.feature)
    #expect(harness.model.liveTerminalCount == 2, "saved tabs still warm up on a visit")
  }

  @Test func theActionsMenuOpensOneTabInTheWorktreeItWasAskedFor() {
    let harness = Harness()
    harness.model.select(harness.main)
    #expect(harness.model.select(harness.feature, openingFirstTab: .never))
    harness.model.newShellTab()

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(
      harness.model.workspace.tabs(in: harness.feature.id).count == 1,
      "not a first tab and then another")
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1)
  }

  @Test func turningToAWorktreeStartsTheAgentWhereAutoStartOnTabOpenIsOn() {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.setAutoStartsAgent(true)

    harness.model.select(harness.main)

    let tab = harness.model.workspace.activeTab(in: harness.main.id)
    #expect(harness.model.workspace.session(tab!.focusedSessionID)?.agentID == "claude")
  }

  @Test func selectingAMissingWorktreeSaysSoInsteadOfActingOnTheSelectedOne() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: harness.project.id,
      head: "c", branch: "ghost")
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, ghost], forProject: harness.project.id)

    #expect(
      !harness.model.select(ghost, openingFirstTab: .never), "the menu must not open a tab in main")
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1)
  }

  @Test func savedTabsInAnUnvisitedWorktreeStayCold() {
    let harness = Harness()
    harness.store.openTab(in: harness.feature.id)
    harness.store.openTab(in: harness.feature.id)
    harness.model.select(harness.main)

    #expect(harness.model.workspace.sessions.count == 3)
    #expect(harness.model.liveTerminalCount == 1, "only the selected worktree's shell is live")

    harness.model.select(harness.feature)
    #expect(
      harness.model.liveTerminalCount == 3, "visiting warms the saved tabs, and main stays warm")
  }

  @Test func selectingAWorktreeWhoseDirectoryIsGoneIsRefused() {
    let harness = Harness()
    let ghost = Worktree(
      path: URL(fileURLWithPath: "/nowhere/\(UUID().uuidString)"), projectID: harness.project.id,
      head: "c", branch: "ghost")
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, ghost], forProject: harness.project.id)
    harness.model.presentedError = nil

    harness.model.select(ghost)

    #expect(harness.model.workspace.selectedWorktreeID == nil)
    #expect(harness.model.presentedError?.title == "Worktree directory is missing")
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func selectingAWorktreeOnAVolumeThatDoesNotAnswerIsRefusedWithoutWaitingForIt() {
    let harness = Harness()
    let stat = HangingStat()
    defer { stat.release() }
    harness.model.directoryProbe = DirectoryProbe(bound: .milliseconds(50), exists: stat.exists)
    harness.model.presentedError = nil

    harness.model.select(harness.feature)
    harness.model.select(harness.feature)

    #expect(!stat.hasReturned)
    #expect(stat.calls == 1, "a second stat would pile another thread onto the mount")
    #expect(harness.model.workspace.selectedWorktreeID == nil)
    #expect(
      harness.model.presentedError?.title == PresentedError.worktreeDirectoryUnanswered("").title)
    #expect(harness.model.liveTerminalCount == 0)
  }
}
