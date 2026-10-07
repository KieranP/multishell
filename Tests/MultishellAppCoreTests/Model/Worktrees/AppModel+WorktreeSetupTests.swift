import Foundation
import MultishellGitKit
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct AppModelWorktreeSetupTests {
  @Test func aFailingHookStillShowsAndSelectsTheWorktree() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "exit 3"), for: harness.project)

    await harness.model.createWorktree(
      branch: "hooked", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "hooked"))
    #expect(harness.model.workspace.selectedWorktreeID == created.id, "shown before the hook ends")
    harness.model.presentedError = nil
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    // In the pane, not an alert: an alert raised while the sheet is still
    // going away is lost, and one raised later lands over other work.
    #expect(harness.model.presentedError == nil)
    let failed = try #require(harness.model.worktreeOperations[created.id])
    #expect(!failed.isRunning && failed.stage == .postCreateHook)
    #expect(failed.title == "The post-create hook failed")
    #expect(harness.model.isBusy(created.id), "held until dismissed")
    #expect(harness.model.liveTerminalCount == 0)

    harness.model.dismissOperationFailure(of: created)
    #expect(harness.model.worktreeOperations.isEmpty)
    #expect(harness.model.workspace.selectedWorktreeID == created.id)
    #expect(harness.model.liveTerminalCount == 1, "dismissing hands over to a shell")
  }

  @Test func aFailedHooksOutputIsWhatThePaneShows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "echo installing\necho npm said no >&2\nexit 1"),
      for: harness.project)

    await harness.model.createWorktree(
      branch: "loud", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "loud"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(
      harness.model.worktreeOperations[created.id]?.failure
        == "installing\nnpm said no\n\nExited with status 1.",
      "what the hook printed on either stream, then its status, and no rc noise")
  }
  /// `npm install` in a post-create hook used to hold the sheet, and the whole app, for as
  /// long as it took.
  @Test func aSlowPostCreateHookReturnsAtOnceShowsItsProgressAndHoldsTheFirstTab() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "sleep 3"), for: harness.project)

    await harness.model.createWorktree(
      branch: "slow", basedOn: nil, createsBranch: true, in: harness.project)

    let created = try #require(harness.worktree(onBranch: "slow"))
    // No clock needed: a create that waited out the hook would leave the operation
    // finished and the first tab open, which the next three read.
    #expect(harness.model.workspace.selectedWorktreeID == created.id)
    #expect(harness.model.worktreeOperations[created.id]?.stage == .postCreateHook)
    #expect(harness.model.isBusy(created.id))
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty, "no shell until the hook is done")
    #expect(harness.model.liveTerminalCount == 0)

    harness.model.newTab()
    harness.model.newShellTab()
    harness.model.select(created)
    #expect(
      harness.model.workspace.tabs(in: created.id).isEmpty, "nothing starts a shell meanwhile")
    harness.model.requestWorktreeRemoval(of: created)
    #expect(harness.model.pendingWorktreeRemoval == nil, "and nothing removes it meanwhile")

    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(harness.model.presentedError == nil)
    #expect(harness.model.worktreeOperations.isEmpty)
    #expect(harness.model.workspace.tabs(in: created.id).count == 1, "the held-back first tab")
    #expect(harness.model.liveTerminalCount == 1)
  }

  @Test func hooksRunThroughTheProjectsShellOverride() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let shells = harness.root.appendingPathComponent("shells", isDirectory: true)
    try FileManager.default.createDirectory(at: shells, withIntermediateDirectories: true)
    let (zsh, bash) = (shells.appendingPathComponent("zsh"), shells.appendingPathComponent("bash"))
    try Scratch.script("printf zsh > shell.txt", at: zsh)
    try Scratch.script("printf bash > shell.txt", at: bash)
    harness.model.setPreferredShell(zsh.path)
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "true", preferredShellID: bash.path), for: harness.project)

    await harness.model.createWorktree(
      branch: "bashed", basedOn: nil, createsBranch: true, in: harness.project)

    let created = try #require(harness.worktree(onBranch: "bashed"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    let shell = try String(
      contentsOf: created.path.appendingPathComponent("shell.txt"), encoding: .utf8)
    #expect(shell == "bash", "the project's shell, not the global one")
  }

  @Test func aHookThatLeavesABackgroundProcessDoesNotHangTheCreate() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "sleep 30 & echo $! > sleep.pid"), for: harness.project)

    await harness.model.createWorktree(
      branch: "served", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "served"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value
    let written = try String(
      contentsOf: created.path.appendingPathComponent("sleep.pid"), encoding: .utf8)
    let hookChild = try #require(pid_t(written.trimmingCharacters(in: .whitespacesAndNewlines)))
    defer { kill(hookChild, SIGKILL) }

    #expect(harness.model.presentedError == nil)
    #expect(harness.model.worktreeOperations.isEmpty)
    #expect(kill(hookChild, 0) == 0, "the setup ended without waiting on the hook's child")
  }

  @Test func aPostCreateHookPastTheTimeoutIsStoppedAndThePaneSaysItDidNotFinish() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setHookTimeoutSeconds(1)
    harness.model.setSettings(
      ProjectSettings(postCreateHook: "echo installing\nsleep 30"), for: harness.project)
    let started = ContinuousClock.now

    await harness.model.createWorktree(
      branch: "slow", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "slow"))
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(ContinuousClock.now - started < .seconds(10))
    let failed = try #require(harness.model.worktreeOperations[created.id])
    #expect(failed.didTimeOut && failed.title == "The post-create hook did not finish")
    #expect(failed.failure == "installing\n\nStopped after 1 second, the hook timeout.")
    #expect(harness.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")
  }

  @Test func cancelEndsAPostCreateHookAndHandsTheWorktreeOver() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "sleep 30"), for: harness.project)

    await harness.model.createWorktree(
      branch: "stopped", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "stopped"))
    #expect(harness.model.worktreeOperations[created.id]?.isRunning == true)
    harness.model.cancelStage(of: created)
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(harness.model.worktreeOperations[created.id] == nil, "nothing to dismiss")
    #expect(harness.model.presentedError == nil)
    #expect(
      harness.model.workspace.tabs(in: created.id).count == 1,
      "the first tab opens as after a finish")
  }
  /// A stage ending is not the user turning back to the pane, so the board
  /// stays up and the first tab opens behind it.
  @Test func aStageEndingUnderTheAgentsBoardLeavesTheBoardUpAndStartsTheTabBehindIt()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setOpensTerminalOnSelect(false)
    harness.model.setOpensTerminalOnCreate(true)
    harness.model.setSettings(ProjectSettings(postCreateHook: "sleep 30"), for: harness.project)

    await harness.model.createWorktree(
      branch: "roster", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "roster"))
    harness.model.showAgentBoard()
    harness.model.cancelStage(of: created)
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    #expect(harness.model.showsAgentBoard, "nothing the user did")
    let tabs = harness.model.workspace.tabs(in: created.id)
    #expect(tabs.count == 1, "owed by the create, not the select")
    #expect(harness.engine.liveSessionIDs.contains(tabs[0].focusedSessionID), "and running already")
    #expect(harness.engine.focused.isEmpty, "the keyboard is left where it was")
  }
  /// The first tab is the create's, so it opens under the create settings,
  /// agent included, without taking the keyboard from where the user is.
  @Test func aCreateFinishedOutOfViewStartsItsFirstTabInTheBackground() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setOpensTerminalOnSelect(false)
    harness.model.setOpensTerminalOnCreate(true)
    harness.model.setAutoStartsAgentOnCreate(true)
    harness.model.setPreferredAgent("claude")
    harness.model.setSettings(ProjectSettings(postCreateHook: "sleep 30"), for: harness.project)
    let main = harness.model.workspace.worktrees(of: harness.project.id)[0]

    await harness.model.createWorktree(
      branch: "owed", basedOn: nil, createsBranch: true, in: harness.project)
    let created = try #require(harness.worktree(onBranch: "owed"))
    harness.model.select(main)
    let focusedBefore = harness.engine.focused.count
    harness.model.cancelStage(of: created)
    await harness.model.stageHandles.setupTask(of: created.id)?.value

    let tabs = harness.model.workspace.tabs(in: created.id)
    #expect(tabs.count == 1)
    #expect(
      harness.model.workspace.session(tabs[0].focusedSessionID)?.agentID == "claude",
      "the create pair of settings, not the select pair")
    #expect(
      harness.engine.liveSessionIDs.contains(tabs[0].focusedSessionID), "started in the background")
    #expect(harness.model.workspace.selectedWorktreeID == main.id, "the user was not moved")
    #expect(harness.engine.focused.count == focusedBefore, "nor was the keyboard")
    harness.model.select(created)
    #expect(harness.model.workspace.tabs(in: created.id).count == 1, "nothing more on the visit")
  }
}
