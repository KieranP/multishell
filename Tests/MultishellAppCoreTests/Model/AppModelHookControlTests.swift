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

  /// The copy runs between `git worktree add` and the hook, so the hook
  /// finds what it was given: an `npm install` wants the `.env` first.
  @Test func listedFilesAreCopiedInBeforeThePostCreateHookRuns() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "cp .env seen.txt", copiedPaths: ".env\nmissing.env"),
      for: h.project)

    await h.model.createWorktree(branch: "copied", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "copied"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "a path the repository does not have is skipped")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1")
  }

  /// The link list runs before the copy list and the hook, and points at
  /// the repository's own file rather than duplicating it.
  @Test func listedFilesAreLinkedInBeforeTheCopyListAndTheHook() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try FileManager.default.createDirectory(
      at: h.project.path.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(
        postCreateHook: "cp .env seen.txt", linkedPaths: "node_modules", copiedPaths: ".env"),
      for: h.project)

    await h.model.createWorktree(branch: "linked", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "linked"))
    // Read before the setup task has had the actor: the stage the pane
    // opens on is the link list, whatever else the project has.
    #expect(h.model.worktreeOperations[created.id]?.step == .linkingFiles)
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil)
    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: created.path.appendingPathComponent("node_modules").path)
        == h.project.path.appendingPathComponent("node_modules").path)
    #expect(
      try String(contentsOf: created.path.appendingPathComponent("seen.txt"), encoding: .utf8)
        == "SECRET=1", "and the copy list, then the hook, ran after it")
    #expect(h.model.worktreeOperations[created.id] == nil, "every stage ended")
  }

  /// The promise a failed stage makes: the list after it and the hook
  /// after that do not run, so one clear failure does not become two.
  @Test func aFailedLinkListStopsTheCopyListAndTheHookAndHoldsTheFirstTab() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try h.divertARepositoryPathWithASymlink()
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try h.shipSharedSettings(
      #"""
      { "linkedPaths": "link/key", "copiedPaths": ".env",
        "postCreateHook": "echo ran > hook.txt" }
      """#)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    await h.model.createWorktree(branch: "stuck", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "stuck"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not linked into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    let manager = FileManager.default
    #expect(
      !manager.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "the copy list after it did not run")
    #expect(!manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path))
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations[created.id] == nil)
    #expect(!h.model.workspace.tabs(in: created.id).isEmpty, "and Dismiss hands the worktree over")
  }

  /// A link list reads the reader's own checkout, so it waits for the same
  /// yes the hook beside it waits for, and one answer covers the file.
  @Test func aRepositorysLinkListWaitsForTheTrustQuestionLikeItsHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try FileManager.default.createDirectory(
      at: h.project.path.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
    try #"{ "linkedPaths": "node_modules", "postCreateHook": "echo ran > hook.txt" }"#
      .write(
        to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    await h.model.createWorktree(branch: "shared", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "shared"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("node_modules").path),
      "untrusted, so the list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
    #expect(h.model.worktreeOperations[created.id] == nil, "the link stage ended")

    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    await h.model.createWorktree(branch: "trusted", basedOn: nil, createBranch: true, in: h.project)
    let second = try #require(h.worktree(onBranch: "trusted"))
    await h.model.workInFlight.setup(of: second.id)?.value

    #expect(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: second.path.appendingPathComponent("node_modules").path)
        == h.project.path.appendingPathComponent("node_modules").path,
      "and once trusted the link list applies")
  }

  /// A file list has no process to signal, so Cancel is asked per path. The
  /// worktree is handed over the way a stopped hook hands it over.
  @Test func cancelOnAFileListEndsTheSetupAndHandsTheWorktreeOver() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: ".env"), for: h.project)

    await h.model.createWorktree(branch: "halted", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "halted"))
    // Before the setup task has had the actor: the stage's handle is made
    // early so the stop lands at its first path, not in a race with it.
    #expect(h.model.worktreeOperations[created.id]?.step == .copyingFiles)
    h.model.cancelStage(of: created)
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "a stop is the user's own doing, not a failure")
    #expect(h.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after it did not run")
    #expect(!h.model.workspace.tabs(in: created.id).isEmpty, "the worktree is the user's to use")
  }

  /// A copy list reads the reader's own checkout, git-ignored files
  /// included, so like the hooks beside it in the file it waits.
  @Test func aRepositorysCopyListWaitsForTheTrustQuestionLikeItsHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    try #"{ "copiedPaths": ".env", "postCreateHook": "echo ran > hook.txt" }"#
      .write(
        to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    await h.model.createWorktree(branch: "shared", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "shared"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent(".env").path),
      "untrusted, so the copy list did not apply")
    #expect(
      !FileManager.default.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and neither did the hook beside it in the same file")
    #expect(h.model.worktreeOperations[created.id] == nil, "the copy stage ended")
    #expect(
      !h.model.workspace.tabs(in: created.id).isEmpty,
      "and the first terminal opened once it had, with no hook to wait for")
  }

  /// The alert would be raised as the sheet went away, which is where one
  /// gets dropped, so a failed copy goes to the pane and holds the tab.
  @Test func aFailedCopyShowsInThePaneAndKeepsThePostCreateHookFromRunning() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try h.divertARepositoryPathWithASymlink()
    try h.shipSharedSettings(
      #"{ "copiedPaths": "link/key", "postCreateHook": "echo ran > hook.txt" }"#)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    await h.model.createWorktree(branch: "escaped", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "escaped"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.presentedError == nil, "not an alert the sheet's dismissal would drop")
    let shown = try #require(h.model.worktreeOperations[created.id])
    #expect(shown.title == "Some files were not copied into the worktree")
    #expect(shown.failure?.contains("link/key") == true)
    #expect(
      !FileManager.default.fileExists(
        atPath: created.path.appendingPathComponent("hook.txt").path),
      "the hook did not run")
    #expect(h.model.workspace.tabs(in: created.id).isEmpty, "held back until dismissed")

    h.model.dismissOperationFailure(of: created)
    #expect(h.model.worktreeOperations[created.id] == nil)
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

    h.model.requestRemoval(of: worktree)
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

  /// The main worktree is the repository. Only a sidebar condition three
  /// modules away kept it off this call, and the trash step would bin `.git`.
  @Test func removingTheMainWorktreeIsRefusedBeforeAnythingRuns() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let marker = h.root.appendingPathComponent("delete-hook-ran")
    h.model.updateSettings(
      ProjectSettings(preDeleteHook: "touch \(marker.path)"), for: h.project)
    let main = try #require(h.worktree(onBranch: "main"))
    #expect(main.isPrimary)

    await h.model.removeWorktree(main)

    #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    #expect(h.platform.trashed.isEmpty, "and nothing went to the Trash")
    #expect(FileManager.default.fileExists(atPath: main.path.path))
    #expect(h.model.presentedError != nil)
  }

  @Test func aLockedWorktreeIsForgottenLockAndAll() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "locked", basedOn: nil, createBranch: true, in: h.project)
    var worktree = try #require(h.worktree(onBranch: "locked"))
    _ = try await h.git.run(["worktree", "lock", worktree.path.path], in: h.project.path)
    await h.model.refresh(h.project)
    worktree = try #require(h.worktree(onBranch: "locked"))
    #expect(worktree.isLocked)

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "locked") == nil, "no record left behind")
    #expect(h.platform.trashed == [worktree.path])
  }

  @Test func aTrashThatRefusesFallsBackToDeletingTheDirectory() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "stuck", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "stuck"))
    h.platform.trash = nil

    await h.model.removeWorktree(worktree)

    #expect(h.model.presentedError == nil)
    #expect(h.worktree(onBranch: "stuck") == nil)
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path), "deleted outright")
    #expect(h.platform.logged.count == 1, "the fallback leaves a line in the log")
  }

  /// The model is on the main actor and a Trash on a network share walks the
  /// whole tree, so the walk must not be where the window's events are.
  @Test func theTrashAndItsFallbackRunOffTheMainThread() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "heavy", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "heavy"))
    h.platform.trash = nil

    await h.model.removeWorktree(worktree)

    #expect(h.platform.trashCallsOnMainThread == [false], "the Trash was asked off the main thread")
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirectoryThatCanBeNeitherTrashedNorDeletedKeepsTheWorktree() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "pinned", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "pinned"))
    h.platform.trash = nil
    // A read-only parent refuses the unlink of its entries.
    let container = worktree.path.deletingLastPathComponent()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: container.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: container.path)
    }

    await h.model.removeWorktree(worktree)

    let alert = try #require(h.model.presentedError)
    #expect(alert.title.hasPrefix("Worktree not removed: the directory could not be moved"))
    #expect(alert.retryLabel == nil)
    #expect(h.worktree(onBranch: "pinned") != nil && h.model.worktreeOperations.isEmpty)
    #expect(FileManager.default.fileExists(atPath: worktree.path.path))
    #expect(h.model.liveTerminalCount == 1, "the shell is still there")
  }

  @Test func theRepositorysSettingsFileFillsTheGapsAndItsHooksWaitForTrust() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try
      #"{ "branchPrefix": "team/", "worktreeDirectory": ".shared-trees", "postCreateHook": "echo shared > hook.txt", "iconGlyph": "hammer" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)

    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.branchPrefix == "team/")
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "team/")
    #expect(h.model.effectiveSettings(for: h.project).iconGlyph == "hammer")
    #expect(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project)?.path.hasSuffix(
        "/.shared-trees/team-x") == false,
      "where a checkout lands waits for trust, unlike the prefix and the icon")
    #expect(h.model.pendingSharedSettingsTrust == nil, "not asked until the user turns to it")
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(pending.projectID == h.project.id && pending.contents.contains("echo shared"))
    #expect(!h.model.trustsSharedSettings(of: h.project))

    // Untrusted: the create runs no hook, and its own select does not ask.
    h.model.pendingSharedSettingsTrust = nil
    await h.model.createWorktree(branch: "a", basedOn: nil, createBranch: true, in: h.project)
    #expect(h.model.pendingSharedSettingsTrust == nil, "the sheet is still going away then")
    let a = try #require(h.worktree(onBranch: "team/a"))
    #expect(h.model.workInFlight.setup(of: a.id) == nil)
    #expect(!FileManager.default.fileExists(atPath: a.path.appendingPathComponent("hook.txt").path))

    h.model.decideSharedSettings(pending, trusted: true)
    #expect(h.model.pendingSharedSettingsTrust == nil)
    #expect(h.model.trustsSharedSettings(of: h.project))
    #expect(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project)?.path.hasSuffix(
        "/.shared-trees/team-x") == true,
      "and once trusted the file's directory is the one used")
    await h.model.createWorktree(branch: "b", basedOn: nil, createBranch: true, in: h.project)
    let b = try #require(h.worktree(onBranch: "team/b"))
    await h.model.workInFlight.setup(of: b.id)?.value
    #expect(FileManager.default.fileExists(atPath: b.path.appendingPathComponent("hook.txt").path))

    // The user's own prefix wins; a changed hook asks again.
    h.model.updateSettings(
      with(h.model.workspace.project(h.project.id)!.settings) { $0.branchPrefix = "me/" },
      for: h.project)
    #expect(h.model.worktreeSettings(for: h.project).branchPrefix == "me/")
    try #"{ "postCreateHook": "echo changed" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(!h.model.trustsSharedSettings(of: h.project))
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    #expect(h.model.pendingSharedSettingsTrust?.contents == "post-create:\necho changed")
  }

  /// What a committed file names outside the checkout is dropped, and the
  /// reader's own settings stand; see Docs/design/settings.md.
  @Test func aSettingsFileCannotPlaceAWorktreeOrReadFilesOutsideTheCheckout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let key = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".ssh/id_ed25519").path
    let json = """
      { "worktreeDirectory": "~/.claude/skills", \
      "linkedPaths": "\(key)\\nvendor", "copiedPaths": "../../.aws/credentials" }
      """
    try json.write(
      to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    // Trusted, so what is dropped here is dropped for reaching out and not
    // for waiting on an answer.
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    let effective = h.model.effectiveSettings(for: h.project)
    #expect(effective.worktreeDirectory == nil, "the reader's own directory stands")
    #expect(effective.linkedPaths == "vendor", "only the entry reaching out is dropped")
    #expect(effective.copiedPaths.isEmpty)

    let planned = try #require(
      h.model.plannedPath(forBranch: "x", createBranch: true, in: h.project))
    #expect(!planned.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/."))
    #expect(planned.path.hasSuffix("-worktrees/x"), "the app default, not the file's")

    await h.model.createWorktree(branch: "x", basedOn: nil, createBranch: true, in: h.project)
    let worktree = try #require(h.worktree(onBranch: "x"))
    await h.model.workInFlight.setup(of: worktree.id)?.value
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("id_ed25519").path))
    #expect(
      !FileManager.default.fileExists(
        atPath: worktree.path.appendingPathComponent("credentials").path))
  }

  /// Asking about a path the app has already refused would show a line that
  /// trusting cannot turn on, and teach the user to say yes to it.
  @Test func theQuestionLeavesOutWhatConfinementHasAlreadyDropped() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try #"{ "linkedPaths": "~/.ssh/id_ed25519\nvendor" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])

    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(pending.contents == "linked:\nvendor")
    #expect(!pending.contents.contains(".ssh"), "not a line the user is asked to allow")
  }

  /// And a file whose every path is refused asks nothing at all: there is
  /// no longer anything a yes would turn on.
  @Test func aFileWhoseEveryPathIsRefusedIsNeverAskedAbout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try #"{ "linkedPaths": "~/.ssh/id_ed25519", "copiedPaths": "/etc/passwd" }"#
      .write(to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)

    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])

    #expect(h.model.pendingSharedSettingsTrust == nil)
    h.model.setTrustsSharedSettings(true, for: h.project)
    #expect(
      !h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!),
      "and the tab's button has nothing to turn on either")
  }

  /// A touch moves the date without changing the bytes. Recording it anyway
  /// is what stops every tick after re-reading the file.
  @Test func aFileWhoseBytesDidNotChangeStillRecordsItsNewDate() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let shared = SharedProjectSettings(branchPrefix: "team/")
    let later = Date(timeIntervalSince1970: 2)

    h.model.noteSharedSettings(
      .success(shared), stamp: Date(timeIntervalSince1970: 1), for: h.project)
    h.model.noteSharedSettings(.success(shared), stamp: later, for: h.project)

    #expect(!h.project.sharedSettings.hasMoved(later), "so the next tick spends no read")
  }

  /// The answer is held against the file's sha256, so a switch back asks
  /// nothing. Real commits: a branch switch is git rewriting the file.
  @Test func switchingBetweenTwoBranchesHooksAsksAboutEachOnce() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let repository = h.project.path
    let file = SharedProjectSettings.file(in: repository)
    func commit(_ json: String, _ message: String) async throws {
      try json.write(to: file, atomically: true, encoding: .utf8)
      _ = try await h.git.run(["add", "."], in: repository)
      _ = try await h.git.run(["commit", "-q", "-m", message], in: repository)
    }

    try await commit(#"{ "postCreateHook": "echo main" }"#, "main hooks")
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "echo main")

    // The other branch's file: bytes nobody has answered for, so asked.
    _ = try await h.git.run(["checkout", "-q", "-b", "feature"], in: repository)
    try await commit(#"{ "postCreateHook": "echo feature" }"#, "feature hooks")
    await h.model.refreshChangedSharedSettings()
    let feature = try #require(h.model.pendingSharedSettingsTrust)
    #expect(feature.contents == "post-create:\necho feature")
    h.model.decideSharedSettings(feature, trusted: false)
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))

    // Back to the first branch: the yes it was given stands, unasked.
    _ = try await h.git.run(["checkout", "-q", "main"], in: repository)
    await h.model.refreshChangedSharedSettings()
    #expect(h.model.pendingSharedSettingsTrust == nil, "answered for already")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "echo main")

    // And back to the other: its no stands, also unasked.
    _ = try await h.git.run(["checkout", "-q", "feature"], in: repository)
    await h.model.refreshChangedSharedSettings()
    #expect(h.model.pendingSharedSettingsTrust == nil, "and the no is not asked again either")
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(h.model.effectiveSettings(for: h.project).postCreateHook == "")

    // The answer is against the file's bytes, so a branch that ships the
    // trusted hooks alongside another key is a file of its own and asks.
    _ = try await h.git.run(["checkout", "-q", "-b", "prefixed", "main"], in: repository)
    try await commit(
      #"{ "branchPrefix": "team/", "postCreateHook": "echo main" }"#, "hooks and a prefix")
    await h.model.refreshChangedSharedSettings()
    #expect(
      h.model.pendingSharedSettingsTrust?.contents == "post-create:\necho main",
      "the same hooks, in bytes nobody has answered for")
  }

  @Test func aSettingsFileEditedWhileTheAppIsUpIsReadOnTheNextTick() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.pendingSharedSettingsTrust == nil, "the first read of a project says nothing")

    // No worktree comes or goes, so the records are the same and the file's
    // date is the only thing that says it changed.
    try #"{ "postCreateHook": "echo two" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshChangedSharedSettings()
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo two")
    #expect(h.model.pendingSharedSettingsTrust == nil, "not a project the user is looking at")

    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let stale = try #require(h.model.pendingSharedSettingsTrust)

    // The file moves on while its question is still up.
    try #"{ "postCreateHook": "echo two and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    let pending = try #require(h.model.pendingSharedSettingsTrust)
    #expect(
      pending.contents == "post-create:\necho two and a half",
      "the question up was about text the file no longer has")

    h.model.decideSharedSettings(pending, trusted: true)
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    #expect(stale.contents != pending.contents)

    // Not over the new-worktree sheet, which the user is answering.
    h.model.newWorktreeRequest = NewWorktreeRequest(projectID: h.project.id)
    try #"{ "postCreateHook": "echo three and a half" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo three and a half")
    #expect(h.model.pendingSharedSettingsTrust == nil, "the sheet is what is being answered")
    h.model.newWorktreeRequest = nil

    try #"{ "postCreateHook": "echo three" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshWorktreesIfRecordsChanged()

    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten?.postCreateHook
        == "echo three")
    #expect(
      h.model.pendingSharedSettingsTrust?.contents == "post-create:\necho three",
      "asked while it is the project on screen")
    #expect(!h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
  }

  @Test func aBrokenSettingsFileIsAProblemOnTheHooksTabNotAnAlert() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "not json".write(
      to: SharedProjectSettings.file(in: h.project.path), atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    #expect(h.model.presentedError == nil)
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.problem?.hasPrefix(
        ".multishell.json could not be read")
        == true)
    #expect(h.model.workspace.project(h.project.id)?.sharedSettings.asWritten == nil)
    #expect(h.platform.logged.count == 1)
  }

  /// A file that stops parsing leaves no hooks to run, so its question is
  /// dropped the way a deleted file's is.
  @Test func aQuestionGoesAwayWithTheFileItWasAbout() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    #expect(h.model.pendingSharedSettingsTrust != nil)

    try "not json".write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshChangedSharedSettings()
    #expect(
      h.model.pendingSharedSettingsTrust == nil, "the hooks it named are not the app's any more")

    // The same for a branch that carries no file at all.
    try #"{ "postCreateHook": "echo one" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refreshChangedSharedSettings()
    #expect(h.model.pendingSharedSettingsTrust != nil, "and comes back when it parses again")
    try FileManager.default.removeItem(at: file)
    await h.model.refreshChangedSharedSettings()
    #expect(h.model.pendingSharedSettingsTrust == nil)
  }

  /// The confinement verdict is held against the file's bytes, so a branch can
  /// add the symlink without moving them. The disk is asked again at the create.
  @Test func aSymlinkCommittedAfterTheFileWasReadCannotCarryACheckoutOut() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "trees" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: true)

    let elsewhere = h.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: h.project.path.appendingPathComponent("trees"), withDestinationURL: elsewhere)

    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)

    #expect(
      try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty,
      "the link leads out of the checkout, so the file's directory is not in force")
    let created = try #require(h.worktree(onBranch: "feat"))
    #expect(!created.path.standardizedFileURL.path.hasPrefix(elsewhere.standardizedFileURL.path))
  }

  /// The dropped verdict is stored, so the read that put it there must not be
  /// the last word: taking the symlink away brings the directory back.
  @Test func takingTheSymlinkAwayBringsTheDirectoryBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "trees" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)
    let link = h.project.path.appendingPathComponent("trees")
    let elsewhere = h.root.appendingPathComponent("elsewhere", isDirectory: true)
    try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: elsewhere)

    _ = await h.model.reconfineSharedSettings(of: h.project)
    #expect(h.project.sharedSettings.confined?.worktreeDirectory == nil)

    try FileManager.default.removeItem(at: link)
    _ = await h.model.reconfineSharedSettings(of: h.project)

    #expect(h.project.sharedSettings.confined?.worktreeDirectory == "trees")
    #expect(h.model.worktreeSettings(for: h.project).worktreeDirectory == "trees")
  }

  /// A key from a teammate's newer build is not the user's to drop, and
  /// nothing but `git diff` would show it gone.
  @Test func exportKeepsAKeyThisBuildDoesNotKnow() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "$schema": "https://example.test/multishell.json", "branchPrefix": "team/" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.updateSettings(ProjectSettings(iconTint: 3), for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    #expect(json["$schema"] as? String == "https://example.test/multishell.json")
    #expect(json["branchPrefix"] as? String == "team/" && json["iconTint"] as? Int == 3)
    #expect(
      h.model.workspace.project(h.project.id)?.sharedSettings.asWritten
        == (try SharedProjectSettings.load(from: h.project.path))
    )
  }

  @Test func exportLeavesOutAGlyphNoBuildCanDraw() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(ProjectSettings(iconGlyph: "🚀", iconTint: 3), for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.iconGlyph == nil, "an emoji left over from an older build is not the team's")
    #expect(written.iconTint == 3, "the tint it was set with still is")
  }

  @Test func exportWritesTheSettingsInForceAndTrustsItsOwnHooks() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.updateSettings(
      ProjectSettings(
        branchPrefix: "team/", postCreateHook: "npm ci", linkedPaths: "node_modules",
        copiedPaths: ".env\n.env.*",
        iconGlyph: "server.rack", iconTint: 3),
      for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "team/" && written.postCreateHook == "npm ci")
    #expect(written.iconGlyph == "server.rack" && written.iconTint == 3)
    #expect(written.copiedPaths == ".env\n.env.*", "the file lists travel with the hooks")
    #expect(written.linkedPaths == "node_modules")
    #expect(
      written.trustedContentText?.contains("copied:\n.env") == true,
      "and are asked about beside them")
    #expect(written.trustedContentText?.contains("linked:\nnode_modules") == true)
    #expect(written.worktreeDirectory == nil, "following the global is not exported")
    #expect(h.model.workspace.project(h.project.id)?.sharedSettings.asWritten == written)
    #expect(h.model.pendingSharedSettingsTrust == nil, "it is all the user's own words")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
    let text = try String(
      contentsOf: SharedProjectSettings.file(in: h.project.path), encoding: .utf8)
    #expect(text.hasPrefix("{\n  \"branchPrefix\""), "sorted and indented for a diff")
  }

  /// Export writes the settings in force, and a refused hook is not in force,
  /// so it is the file's word rather than the user's to drop.
  @Test func exportKeepsAHookTheUserRefusedToTrust() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: false)
    h.model.updateSettings(
      with(h.project.settings) { $0.branchPrefix = "mine/" }, for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.postCreateHook == "npm ci", "what they refused is still the file's")
    let project = try #require(h.model.workspace.project(h.project.id))
    #expect(!h.model.trustsSharedSettings(of: project), "and exporting is not a way to trust it")
    #expect(
      project.settings.sharedSettingsDecision(about: written) == false,
      "the no travels to the new digest, so nothing asks again")
  }

  /// The directory and the two path lists wait for the same yes the hooks do,
  /// so an export before that yes would have dropped them from the file.
  @Test func exportKeepsThePathsTheUserNeverTrusted() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"""
    { "worktreeDirectory": ".trees", "postCreateHook": "npm ci",
      "linkedPaths": "node_modules", "copiedPaths": ".env" }
    """#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.updateSettings(ProjectSettings(branchPrefix: "mine/"), for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.branchPrefix == "mine/", "what the user did set is exported")
    #expect(written.worktreeDirectory == ".trees")
    #expect(written.linkedPaths == "node_modules")
    #expect(written.copiedPaths == ".env")
    #expect(written.postCreateHook == "npm ci")
  }

  /// The yes was given about these words, and export writes them back
  /// unchanged, so the answer travels to the new bytes rather than lapsing.
  @Test func exportCarriesAYesOntoTheFileItRewrites() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "worktreeDirectory": "../trees", "postCreateHook": "npm ci" }"#
      .write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    h.model.decideSharedSettings(try #require(h.model.pendingSharedSettingsTrust), trusted: true)

    h.model.exportSharedSettings(for: h.project)

    let project = try #require(h.model.workspace.project(h.project.id))
    #expect(h.model.trustsSharedSettings(of: project), "the refused directory did not revoke it")
    #expect(h.model.effectiveSettings(for: project).postCreateHook == "npm ci")
  }

  /// Export records an answer it has, never one it does not: writing the
  /// file back is not the user saying no to a teammate's hook.
  @Test func exportDoesNotAnswerAQuestionTheUserWasNeverAsked() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)

    h.model.exportSharedSettings(for: h.project)

    let project = try #require(h.model.workspace.project(h.project.id))
    let shared = try #require(project.sharedSettings.confined)
    #expect(project.settings.needsTrustDecision(for: shared), "so selecting still asks")
  }

  /// A list the user typed is theirs, `RepositoryContainment` holding only
  /// what a repository ships; an entry reaching out is skipped, not refused.
  @Test func aPathTheUserListedThemselvesDoesNotStopTheStagesAfterIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "SECRET=1".write(
      to: h.project.path.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    h.model.updateSettings(
      ProjectSettings(postCreateHook: "echo ran > hook.txt", copiedPaths: "~/.aws.json\n.env"),
      for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "every stage ended")
    let manager = FileManager.default
    #expect(manager.fileExists(atPath: created.path.appendingPathComponent(".env").path))
    #expect(
      manager.fileExists(atPath: created.path.appendingPathComponent("hook.txt").path),
      "and the hook after the list ran")
  }

  /// The user's own list replaces the repository's whole, so what is placed
  /// is theirs and is not held to the checkout, file on disk or not.
  @Test func theUsersOwnListOverridingTheRepositorysIsStillTheirs() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let secret = h.root.appendingPathComponent("secrets.txt")
    try "SECRET=1".write(to: secret, atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      at: h.project.path.appendingPathComponent(".env"), withDestinationURL: secret)
    try h.shipSharedSettings(#"{ "copiedPaths": "vendor" }"#)
    await h.model.refresh(h.project)
    h.model.updateSettings(
      with(h.project.settings) { $0.copiedPaths = ".env" }, for: h.project)

    await h.model.createWorktree(branch: "mine", basedOn: nil, createBranch: true, in: h.project)
    let created = try #require(h.worktree(onBranch: "mine"))
    await h.model.workInFlight.setup(of: created.id)?.value

    #expect(h.model.worktreeOperations[created.id] == nil, "the stage ended rather than failing")
    #expect(
      try String(contentsOf: created.path.appendingPathComponent(".env"), encoding: .utf8)
        == "SECRET=1", "and their symlinked file was placed")
  }

  /// A hook the user wrote themselves still replaces the file's, and that
  /// file is theirs, so it is trusted as before.
  @Test func exportOverwritesAHookWithTheUsersOwn() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let file = SharedProjectSettings.file(in: h.project.path)
    try #"{ "postCreateHook": "npm ci" }"#.write(to: file, atomically: true, encoding: .utf8)
    await h.model.refresh(h.project)
    h.model.select(h.model.workspace.worktrees(of: h.project.id)[0])
    let asked = try #require(h.model.pendingSharedSettingsTrust)
    h.model.decideSharedSettings(asked, trusted: false)
    h.model.updateSettings(ProjectSettings(postCreateHook: "make setup"), for: h.project)

    h.model.exportSharedSettings(for: h.project)

    let written = try #require(try SharedProjectSettings.load(from: h.project.path))
    #expect(written.postCreateHook == "make setup")
    #expect(h.model.trustsSharedSettings(of: h.model.workspace.project(h.project.id)!))
  }
}

private func with(
  _ settings: ProjectSettings, _ change: (inout ProjectSettings) -> Void
)
  -> ProjectSettings
{
  var updated = settings
  change(&updated)
  return updated
}
