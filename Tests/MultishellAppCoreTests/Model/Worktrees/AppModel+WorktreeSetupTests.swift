import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelWorktreeSetupTests {
  @Test func aFailingHookStillShowsAndSelectsTheWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "exit 3"), for: h.project)

    await h.model.createWorktree(branch: "hooked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "hooked"))
    #expect(h.model.workspace.selectedWorktreeID == created.id, "shown before the hook ends")
    h.model.presentedError = nil
    await h.model.stageHandles.setup(of: created.id)?.value

    // In the pane, not an alert: an alert raised while the sheet is still
    // going away is lost, and one raised later lands over other work.
    #expect(h.model.presentedError == nil)
    let failed = try #require(h.model.worktreeOperations[created.id])
    #expect(!failed.isRunning && failed.step == .postCreateHook)
    #expect(failed.title == "The post-create hook failed")
    #expect(h.model.isBusy(created.id), "held until dismissed")
    #expect(h.model.liveTerminalCount == 0)

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.liveTerminalCount == 1, "dismissing hands over to a shell")
  }

  @Test func aFailedHooksOutputIsWhatThePaneShows() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo installing\necho npm said no >&2\nexit 1"),
      for: h.project)

    await h.model.createWorktree(branch: "loud", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "loud"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(
      h.model.worktreeOperations[created.id]?.failure
        == "installing\nnpm said no\n\nExited with status 1.",
      "what the hook printed on either stream, then its status, and no rc noise")
  }
  /// `npm install` in a post-create hook used to hold the sheet, and the whole app, for as
  /// long as it took.
  @Test func aSlowPostCreateHookReturnsAtOnceShowsItsProgressAndHoldsTheFirstTab() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 3"), for: h.project)

    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "slow"))
    // No clock needed: a create that waited out the hook would leave the operation
    // finished and the first tab open, which the next three read.
    #expect(h.model.workspace.selectedWorktreeID == created.id)
    #expect(h.model.worktreeOperations[created.id]?.step == .postCreateHook)
    #expect(h.model.isBusy(created.id))
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "no shell until the hook is done")
    #expect(h.model.liveTerminalCount == 0)

    h.model.newTab()
    h.model.newShellTab()
    h.model.select(created)
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "nothing starts a shell meanwhile")
    h.model.requestWorktreeRemoval(of: created)
    #expect(h.model.pendingWorktreeRemoval == nil, "and nothing removes it meanwhile")

    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(h.model.workspace.tabs(in: created.id).count == 1, "the held-back first tab")
    #expect(h.model.liveTerminalCount == 1)
  }

  @Test func hooksRunThroughTheProjectsShellOverride() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let shells = h.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let (zsh, bash) = (shells.appendingPathComponent("zsh"), shells.appendingPathComponent("bash"))
    try Scratch.script("printf zsh > shell.txt", at: zsh)
    try Scratch.script("printf bash > shell.txt", at: bash)
    h.model.setPreferredShell(zsh.path)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "true", preferredShellID: bash.path), for: h.project)

    await h.model.createWorktree(branch: "bashed", basedOn: nil, createBranch: true, in: h.project)

    let created = try #require(h.worktree(onBranch: "bashed"))
    await h.model.stageHandles.setup(of: created.id)?.value
    let shell = try String(
      contentsOf: created.path.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(shell == "bash", "the project's shell, not the global one")
  }

  @Test func aHookThatLeavesABackgroundProcessDoesNotHangTheCreate() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "sleep 30 & echo $! > sleep.pid"), for: h.project)

    await h.model.createWorktree(branch: "served", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "served"))
    await h.model.stageHandles.setup(of: created.id)?.value
    let written = try String(
      contentsOf: created.path.appendingPathComponent("sleep.pid"), encoding: .utf8)
    let hookChild = try #require(pid_t(written.trimmingCharacters(in: .whitespacesAndNewlines)))
    defer { kill(hookChild, SIGKILL) }

    #expect(h.model.presentedError == nil)
    #expect(h.model.worktreeOperations.isEmpty)
    #expect(kill(hookChild, 0) == 0, "waited on the hook's child until it exited")
  }

  @Test func aPostCreateHookPastTheTimeoutIsStoppedAndThePaneSaysItDidNotFinish() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setHookTimeoutSeconds(1)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo installing\nsleep 30"), for: h.project)
    let started = ContinuousClock.now

    await h.model.createWorktree(branch: "slow", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "slow"))
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(ContinuousClock.now - started < .seconds(10))
    let failed = try #require(h.model.worktreeOperations[created.id])
    #expect(failed.timedOut && failed.title == "The post-create hook did not finish")
    #expect(failed.failure == "installing\n\nStopped after 1 second, the hook timeout.")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")
  }

  @Test func cancelEndsAPostCreateHookAndHandsTheWorktreeOver() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    await h.model.createWorktree(branch: "stopped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "stopped"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)
    h.model.cancelStage(of: created)
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "nothing to dismiss")
    #expect(h.model.presentedError == nil)
    #expect(
      h.model.workspace.tabs(in: created.id).count == 1, "the first tab opens as after a finish")
  }
  /// A stage ending is not the user turning back to the pane, so the board
  /// stays up and the first tab opens behind it.
  @Test func aStageEndingUnderTheAgentsBoardLeavesTheBoardUpAndStartsTheTabBehindIt()
    async throws
  {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setOpensTerminalOnSelect(false)
    h.model.setOpensTerminalOnCreate(true)
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    await h.model.createWorktree(branch: "roster", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "roster"))
    h.model.showAgentBoard()
    h.model.cancelStage(of: created)
    await h.model.stageHandles.setup(of: created.id)?.value

    #expect(h.model.showsAgentBoard, "nothing the user did")
    let tabs = h.model.workspace.tabs(in: created.id)
    #expect(tabs.count == 1, "owed by the create, not the select")
    #expect(h.engine.openSessionIDs.contains(tabs[0].focusedSessionID), "and running already")
    #expect(h.engine.focused.isEmpty, "the keyboard is left where it was")
  }
  /// The first tab is the create's, so it opens under the create settings,
  /// agent included, without taking the keyboard from where the user is.
  @Test func aCreateFinishedOutOfViewStartsItsFirstTabInTheBackground() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.setOpensTerminalOnSelect(false)
    h.model.setOpensTerminalOnCreate(true)
    h.model.setAutoStartAgentOnCreate(true)
    h.model.setPreferredAgent("claude")
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)
    let main = h.model.workspace.worktrees(of: h.project.id)[0]

    await h.model.createWorktree(branch: "owed", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "owed"))
    h.model.select(main)
    let focusedBefore = h.engine.focused.count
    h.model.cancelStage(of: created)
    await h.model.stageHandles.setup(of: created.id)?.value

    let tabs = h.model.workspace.tabs(in: created.id)
    #expect(tabs.count == 1)
    #expect(
      h.model.workspace.session(tabs[0].focusedSessionID)?.agentID == "claude",
      "the create pair of settings, not the select pair")
    #expect(h.engine.openSessionIDs.contains(tabs[0].focusedSessionID), "started in the background")
    #expect(h.model.workspace.selectedWorktreeID == main.id, "the user was not moved")
    #expect(h.engine.focused.count == focusedBefore, "nor was the keyboard")
    h.model.select(created)
    #expect(h.model.workspace.tabs(in: created.id).count == 1, "nothing more on the visit")
  }
}
