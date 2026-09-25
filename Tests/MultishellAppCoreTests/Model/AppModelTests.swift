import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

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

  @Test func launchRefreshesTheFilesAndSweepsTheDropsOnceAndSaysWhatFailed() async throws {
    let h = Harness()
    let calls = LineRecorder()
    h.model.refreshLaunchFiles = { _ in
      calls.record("refresh")
      return CocoaError(.fileWriteNoPermission)
    }
    h.model.sweepPromisedDropCopies = { calls.record("sweep") }

    await h.model.start()

    try await waitUntil { calls.received.count == 2 }
    #expect(calls.received == ["refresh", "sweep"])
    #expect(
      h.model.presentedError?.message
        == PresentedError(CocoaError(.fileWriteNoPermission)).message)
  }

  @Test func launchOpensTerminalsWithoutWaitingForTheDroppedFileSweep() async throws {
    let h = Harness()
    let gate = LineRecorder()
    h.model.sweepPromisedDropCopies = {
      let giveUp = Date().addingTimeInterval(10)
      while !gate.received.contains("open"), Date() < giveUp { usleep(1000) }
      gate.record("finished")
    }

    await h.model.start()
    let finishedFirst = gate.received.contains("finished")
    gate.record("open")

    #expect(!finishedFirst)
    try await waitUntil { gate.received.contains("finished") }
  }

  @Test func aSecondCopyOfTheAppHandsOverToTheRunningOneAndSavesNothing() async {
    let file = Scratch.path("second-copy").appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let h = Harness(stateFile: file)
    h.source.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")

    await h.model.start()

    #expect(h.platform.handedOverToRunningInstance)
    #expect(h.model.statusPolling == nil, "this copy does nothing more")
    h.model.select(h.main)
    try? await Task.sleep(for: .milliseconds(600))
    #expect(!FileManager.default.fileExists(atPath: file.path), "the debounce is a writer too")
    h.model.saveNow()
    #expect(!FileManager.default.fileExists(atPath: file.path), "two writers of one file")
  }

  @Test func aCopyThatCouldNotQuitAfterHandingOverStartsNoShell() async {
    let h = Harness()
    h.source.startError = SocketFailure(kind: .inUse, path: "/tmp/multishell.sock")
    await h.model.start()

    h.model.select(h.main)
    h.model.newTab()

    #expect(h.engine.opened.isEmpty, "its config would outlive its quit")
    #expect(h.model.liveTerminalCount == 0)
  }

  @Test func removingTheMainWorktreeIsRefusedBeforeAnyDialog() {
    let h = Harness()
    h.model.requestWorktreeRemoval(of: h.main)
    #expect(h.model.pendingWorktreeRemoval == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(!h.main.isRemovable)
    #expect(h.feature.isRemovable)
  }

  @Test func removalAsksUnlessTheGlobalSettingsSettleBothTheWorktreeAndTheBranch() async {
    let h = Harness()
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == h.feature.id)
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 2)

    h.model.pendingWorktreeRemoval = nil
    h.model.setConfirmsWorktreeRemoval(false)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.id == h.feature.id, "the branch question is still open")
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 2)

    h.model.pendingWorktreeRemoval = nil
    h.model.setDeletesBranchWithWorktree(true)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(
      h.model.pendingWorktreeRemoval == nil,
      "goes straight to removal, which needs git and so no-ops here")

    h.model.setConfirmsWorktreeRemoval(true)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.deletesBranch == true)
    #expect(h.model.pendingWorktreeRemoval?.choices.count == 1)

    h.model.pendingWorktreeRemoval = nil
    h.model.setTrashesRemovedWorktrees(false)
    await h.model.requestWorktreeRemoval(of: h.feature)?.value
    #expect(h.model.pendingWorktreeRemoval?.message(warning: nil).hasPrefix("Deletes ") == true)
  }

  @Test func selectedProjectFollowsSelectionOrTheOnlyProject() {
    let h = Harness()
    #expect(h.model.selectedProject?.id == h.project.id, "one project, nothing selected")
    h.store.addProject(at: URL(fileURLWithPath: "/other"))
    #expect(h.model.selectedProject == nil, "two projects, nothing selected")
    h.model.select(h.feature)
    #expect(h.model.selectedProject?.id == h.project.id)
  }

  @Test func aFailingSaveIsReportedOnceNotAfterEveryChange() async {
    // A file where a directory is needed: nothing can be created under it.
    let h = Harness(stateFile: URL(fileURLWithPath: "/dev/null/multishell/state.json"))
    h.model.presentedError = nil

    h.model.save()
    let first = await h.presentedErrorArrives()
    #expect(first != nil)

    h.model.save()
    h.model.save()
    h.model.presentedError = nil
    #expect(await h.presentedErrorArrives() == nil, "the same alert, not a new one each time")
  }
}
