import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelWorktreeOrderTests {
  /// A third worktree, so an order is visible rather than merely a pair.
  private func harnessWithThreeWorktrees() -> (Harness, Worktree) {
    let harness = Harness()
    let extra = Worktree(
      path: harness.project.path.appendingPathComponent("aardvark"),
      projectID: harness.project.id, head: "c", branch: "aardvark")
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, extra], forProject: harness.project.id)
    return (harness, extra)
  }

  @Test func theRowsFollowTheGlobalOrderWithTheMainWorktreeFirst() {
    let (harness, _) = harnessWithThreeWorktrees()
    let all = harness.model.workspace.worktrees

    let rows = harness.model.orderedWorktrees(
      all, in: harness.project, sessions: harness.model.sessionIDsByWorktree)
    #expect(rows.map(\.name) == ["main", "aardvark", "feature"])
    #expect(rows.first?.id == harness.main.id, "the trunk holds the top")
  }

  /// The project's override beats the global, and the whole way through:
  /// the setting is written as the form writes it.
  @Test func aProjectsOverrideChangesItsRows() {
    let (harness, _) = harnessWithThreeWorktrees()
    var settings = harness.project.settings
    settings.worktreeSortOrder = WorktreeSortOrder.committedNewestFirst
    harness.model.setSettings(settings, for: harness.project)
    harness.model.lastCommitDates[harness.feature.id] = Date(timeIntervalSince1970: 2000)

    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.orderedWorktrees(
        all, in: harness.project, sessions: harness.model.sessionIDsByWorktree
      ).map(\.name)
        == ["main", "feature", "aardvark"], "the dated branch leads, the undated follows")
  }

  @Test func activeMeansATerminalOrAReportedState() {
    let (harness, extra) = harnessWithThreeWorktrees()
    #expect(
      !harness.model.isActiveWorktree(
        harness.feature.id, sessions: harness.model.sessionIDsByWorktree))
    #expect(!harness.model.isActiveWorktree(extra.id, sessions: harness.model.sessionIDsByWorktree))

    harness.store.openTab(in: harness.feature.id)
    #expect(
      harness.model.isActiveWorktree(
        harness.feature.id, sessions: harness.model.sessionIDsByWorktree), "a terminal is enough")

    harness.stateSource.send(
      SessionStateReport(state: .attention, workingDirectory: extra.path.path))
    #expect(
      harness.model.isActiveWorktree(extra.id, sessions: harness.model.sessionIDsByWorktree),
      "so is a state with no terminal")
  }

  @Test func showActiveAtTheTopLiftsTheBusyRow() {
    let (harness, _) = harnessWithThreeWorktrees()
    harness.store.openTab(in: harness.feature.id)
    var settings = harness.project.settings
    settings.showsActiveWorktreesFirst = true
    harness.model.setSettings(settings, for: harness.project)

    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.orderedWorktrees(
        all, in: harness.project, sessions: harness.model.sessionIDsByWorktree
      ).map(\.name)
        == ["main", "feature", "aardvark"], "feature is busy, aardvark only sorts earlier")

    settings.showsActiveWorktreesFirst = false
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all, in: harness.project, sessions: harness.model.sessionIDsByWorktree
      ).map(\.name)
        == ["main", "aardvark", "feature"], "off, the name decides again")
  }
}
