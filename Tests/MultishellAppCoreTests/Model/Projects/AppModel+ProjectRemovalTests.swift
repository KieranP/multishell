import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelProjectRemovalTests {
  /// Pruned by the next `refreshStatuses` against the workspace, which is
  /// cheaper than walking every worktree on a removal.
  private static let prunedByTheNextStatusRead = "_statuses"
  /// A coalesced refresh that finds its worktree gone and does nothing.
  private static let ignoredWhenItFires = "pendingStatusRefreshes"
  /// Fields meant to still name a departed project.
  private static let exempt: Set = [prunedByTheNextStatusRead, ignoredWhenItFires]

  /// Removing the project covers the hooks in it. The `sleep 30` is what
  /// proves the signal, the setup task not being awaitable.
  @Test func removingAProjectEndsAHookStillRunningInItsWorktrees() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(postCreateHook: "sleep 30"), for: harness.project)

    // `harness.project` re-read each time: the create takes its hooks off the
    // value it is handed, so a copy from before the settings write has none.
    await harness.model.createWorktree(
      branch: "setup",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let created = try #require(harness.worktree(onBranch: "setup"))
    #expect(harness.model.worktreeOperations[created.id]?.isRunning == true)

    // Taken before the removal, which is what clears the entry.
    let setup = harness.model.stageHandles.setupTask(of: created.id)
    harness.model.removeProject(harness.project)
    await setup?.value

    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.worktreeOperations[created.id] == nil)
    #expect(harness.model.stageHandles.setupTask(of: created.id) == nil)
    #expect(
      harness.model.presentedError == nil,
      "the user asked for this, so there is nothing to report",
    )
    #expect(
      harness.model.workspace.tabs(in: created.id).isEmpty,
      "and no first tab opens in a worktree whose project has gone",
    )
  }

  /// Walked by reflection rather than field by field, so a path-keyed cache added later is
  /// caught without anyone remembering to extend this test.
  @Test func removingAProjectLeavesNoRuntimeTraceOfIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let project = harness.project

    // A `.multishell.json` and a second worktree give the shared-settings cache, the merge scan
    // and the record check something to hold before the project goes.
    try harness.writeSharedSettings(#"{"branchPrefix": "team/"}"#)
    await harness.model.createWorktree(
      branch: "second",
      basedOn: nil,
      createsBranch: true,
      in: project,
    )
    await harness.model.refreshAll()
    let worktrees = harness.model.workspace.worktrees(of: project.id)
    _ = harness.model.select(worktrees[0])
    // The references a window and a row hold, which no refresh will come
    // back to clear once the project has left.
    harness.model.beginRenamingWorktree(worktrees[0])
    harness.model.requestSettings(for: project)
    // The dialogs a second scene can leave standing over a removal.
    harness.model.requestNewWorktree(in: project)
    await harness.model.requestWorktreeRemoval(of: worktrees[1])?.value

    let paths = Set(
      [project.id] + harness.model.workspace.worktrees(of: project.id).map(\.id)
    )
    #expect(paths.count >= 2, "the project and at least one worktree of its own")
    #expect(
      harness.model.workspace.project(project.id)?.sharedSettingsSnapshot.hasBeenRead == true,
      "the file was read, so the project holds something",
    )

    harness.model.removeProject(project)

    for (field, value) in ModelTraces.find(paths, in: harness.model, exempting: Self.exempt) {
      #expect(Bool(false), "\(field) still names \(value) after its project was removed")
    }
  }

  @Test func removingAProjectAsksFirstInTheWindowThatAsked() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    #expect(harness.model.liveTerminalCount == 1)

    harness.model.requestProjectRemoval(harness.project, from: .settings)

    let pending = try #require(harness.model.pendingProjectRemoval)
    #expect(pending.project.id == harness.project.id)
    #expect(pending.source == .settings)
    #expect(harness.model.workspace.projects.count == 1, "nothing removed until confirmed")
    #expect(
      harness.model.projectRemovalMessage(for: harness.project).contains(
        "1 open terminal will be closed"
      )
    )

    harness.model.answerProjectRemoval(pending, confirmed: true)
    #expect(harness.model.pendingProjectRemoval == nil)
    #expect(harness.model.workspace.projects.isEmpty)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func eachWindowPresentsOnlyTheProjectRemovalItAskedFor() {
    let harness = Harness()
    harness.model.requestProjectRemoval(harness.project, from: .settings)

    #expect(harness.model.pendingProjectRemoval(for: .settings)?.project.id == harness.project.id)
    #expect(harness.model.pendingProjectRemoval(for: .workspace) == nil)
  }

  @Test func cancellingAProjectRemovalTakesTheDialogDownAndKeepsTheProject() throws {
    let harness = Harness()
    harness.model.requestProjectRemoval(harness.project, from: .workspace)
    let pending = try #require(harness.model.pendingProjectRemoval)

    harness.model.answerProjectRemoval(pending, confirmed: false)

    #expect(harness.model.pendingProjectRemoval == nil)
    #expect(harness.model.workspace.projects.count == 1)
  }

  /// Paths are ids, so a project added again gets its old worktree ids, and dates read
  /// before it left would order its rows until the first poll answered.
  @Test func removingAProjectForgetsItsCommitDates() {
    let harness = Harness()
    harness.model.lastCommitDates[harness.main.id] = Date(timeIntervalSince1970: 1000)
    harness.model.lastCommitDates[harness.feature.id] = Date(timeIntervalSince1970: 2000)

    harness.model.removeProject(harness.project)
    #expect(harness.model.lastCommitDates.isEmpty)
  }
}
