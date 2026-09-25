import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// Bare repositories, the hook timeout and the pane's Cancel, removal through the
/// Trash, and the repository's own settings file, on the model with real git.
@Suite(.serialized) @MainActor
struct AppModelHookControlTests {
  @Test func aBareCloneIsAddedAsAProjectWithItsBareEntryFirst() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let bare = h.root.appendingPathComponent("repo.git", isDirectory: true)
    _ = try await h.git.run(["clone", "-q", "--bare", h.project.path.path, bare.path], in: h.root)
    let checkout = h.root.appendingPathComponent("checkout", isDirectory: true)
    _ = try await h.git.run(["worktree", "add", "-q", checkout.path, "main"], in: bare)

    await h.model.addProject(at: checkout)

    #expect(h.model.presentedError == nil)
    let project = try #require(h.model.workspace.project(bare.standardizedFileURL.path))
    #expect(project.name == "repo")
    let worktrees = h.model.workspace.worktrees(of: project.id)
    #expect(worktrees.map(\.isBare) == [true, false])
    #expect(worktrees[0].isPrimary && worktrees[1].branch == "main")
    await h.model.refreshStatuses()
    #expect(h.model.statuses[worktrees[0].id] == nil, "no status poll for the bare entry")
    #expect(h.model.statuses[worktrees[1].id] != nil)
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
    await h.model.workInFlight.setup(of: created.id)?.value

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
    await h.model.workInFlight.setup(of: created.id)?.value

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
    await h.model.workInFlight.setup(of: created.id)?.value

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
    await h.model.workInFlight.setup(of: created.id)?.value

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

  /// Removing the project covers the hooks in it. The `sleep 30` is what
  /// proves the signal, the setup task not being awaitable.
  @Test func removingAProjectEndsAHookStillRunningInItsWorktrees() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30"), for: h.project)

    // `h.project` re-read each time: the create takes its hooks off the
    // value it is handed, so a copy from before the settings write has none.
    await h.model.createWorktree(branch: "setup", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "setup"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)

    // Taken before the removal, which is what clears the entry.
    let setup = h.model.workInFlight.setup(of: created.id)
    h.model.removeProject(h.project)
    await setup?.value

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(h.model.workInFlight.setup(of: created.id) == nil)
    #expect(h.model.presentedError == nil, "the user asked for this, so there is nothing to report")
    #expect(
      h.model.workspace.tabs(in: created.id).isEmpty,
      "and no first tab opens in a worktree whose project has gone")
  }

  /// The worktree goes in a terminal instead: the tick drops the row, and
  /// the hook running there has no pane left to Cancel from, so it is ended.
  @Test func aWorktreeRemovedOutsideTheAppEndsTheHookStillRunningInIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(postCreateHook: "sleep 30; exit 1"), for: h.project)

    await h.model.createWorktree(branch: "setup", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "setup"))
    #expect(h.model.worktreeOperations[created.id]?.isRunning == true)
    let setup = h.model.workInFlight.setup(of: created.id)
    let began = ContinuousClock.now

    _ = try await h.git.run(
      ["worktree", "remove", "--force", created.path.path], in: h.project.path)
    await h.model.refresh(h.project)
    #expect(h.worktree(onBranch: "setup") == nil, "git no longer lists it")
    await setup?.value

    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(h.model.workInFlight.setup(of: created.id) == nil)
    #expect(h.model.workInFlight.stopper(of: created.id) == nil)
    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(h.model.presentedError == nil, "a worktree that is not there has nothing to report")
  }

  /// A checkout held by an LFS smudge or a credential helper on a dead
  /// network: the sheet's Cancel has to end git as it ends the hook before it.
  @Test func cancelWhileGitAddsTheWorktreeEndsItAndReportsNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let slow = try h.modelOnFakeGit(
      """
      case "$1 $2" in
        "worktree add") sleep 30 ;;
      esac
      """)
    let began = ContinuousClock.now

    let create = Task {
      await slow.createWorktree(branch: "held", basedOn: nil, createBranch: true, in: h.project)
    }
    try await waitUntil { slow.worktreeCreationStep == .addingWorktree }
    #expect(slow.worktreeCreationStep == .addingWorktree)
    slow.cancelWorktreeCreation()
    await create.value

    #expect(ContinuousClock.now - began < .seconds(12), "signalled, not waited out")
    #expect(slow.presentedError == nil, "the user's own Cancel is nothing to report")
    #expect(slow.worktreeCreationStep == nil)
  }

  /// Steps reach the main actor through a hop, and the create clears the
  /// slot as it returns, so a later one must not fill it again.
  @Test func aStepReportedAfterItsCreateEndedIsDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "done", basedOn: nil, createBranch: true, in: h.project)
    #expect(h.model.worktreeCreationStep == nil)

    h.model.noteCreationStep(.addingWorktree, of: ProcessStopper())

    #expect(h.model.worktreeCreationStep == nil, "no create owns that stopper any more")
  }

  /// The settings window is its own scene, so a sheet outlives a removal
  /// confirmed there. Its Create used to add a worktree nothing lists.
  @Test func creatingFromASheetHeldOpenAcrossARemovalTouchesNothingOnDisk() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let project = h.project
    let container = h.model.worktreeSettings(for: project).worktreeContainer(for: project)

    h.model.requestNewWorktree(in: project)
    h.model.removeProject(project)
    #expect(h.model.newWorktreeRequest == nil, "the sheet goes with the project")

    await h.model.createWorktree(branch: "orphan", basedOn: nil, createBranch: true, in: project)

    #expect(h.model.workspace.projects.isEmpty)
    #expect(h.model.presentedError == nil)
    #expect(
      !FileManager.default.fileExists(atPath: container.appendingPathComponent("orphan").path),
      "no worktree directory for a project that has left")
  }

  @Test func cancelOnAPreDeleteHookLeavesTheWorktreeQuietly() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "kept", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "kept"))
    h.model.updateSettings(ProjectSettings(preDeleteHook: "sleep 30"), for: h.project)
    h.model.setConfirmsWorktreeRemoval(false)
    h.model.setDeletesBranchWithWorktree(true)

    h.model.requestWorktreeRemoval(of: worktree)
    try await waitUntil { h.model.worktreeOperations[worktree.id]?.step == .preDeleteHook }
    #expect(h.model.worktreeOperations[worktree.id]?.step == .preDeleteHook)
    h.model.cancelStage(of: worktree)
    await h.awaitOperationEnd(on: worktree.id)

    #expect(h.model.worktreeOperations[worktree.id] == nil)
    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "kept") != nil && h.model.liveTerminalCount == 1)
  }

  @Test func cancellingTheSheetDuringThePreCreateHookCreatesNothingAndSaysNothing() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(preCreateHook: "sleep 30"), for: h.project)
    let create = Task {
      await h.model.createWorktree(branch: "never", basedOn: nil, createBranch: true, in: h.project)
    }
    try await waitUntil { h.model.worktreeCreationStep == .preCreateHook }
    #expect(h.model.worktreeCreationStep == .preCreateHook)

    h.model.cancelWorktreeCreation()
    await create.value

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "never") == nil)
    #expect(h.model.worktreeCreationStep == nil)
  }

  /// git rejects the name at the end of a create, by which time the hook
  /// has run and the container directory is there.
  @Test func aBranchNameGitWillRefuseRunsNoHookAndMakesNoDirectory() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let marker = h.root.appendingPathComponent("hook-ran")
    h.model.updateSettings(
      ProjectSettings(preCreateHook: "touch \(marker.path)"), for: h.project)

    await h.model.createWorktree(
      branch: "my branch", basedOn: nil, createBranch: true, in: h.project)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(h.model.presentedError != nil, "and the sheet says why")
    #expect(h.worktree(onBranch: "my branch") == nil)
  }

  static func with(
    _ settings: ProjectSettings, _ change: (inout ProjectSettings) -> Void
  ) -> ProjectSettings {
    var updated = settings
    change(&updated)
    return updated
  }
}
