import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
@MainActor
struct AppModelWorktreeOrderTests {
  /// A third worktree, so an order is visible rather than merely a pair.
  private func harnessWithThree() -> (Harness, Worktree) {
    let harness = Harness()
    let extra = Worktree(
      path: harness.project.path.appendingPathComponent("aardvark"),
      projectID: harness.project.id, head: "c", branch: "aardvark")
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, extra], forProject: harness.project.id)
    return (harness, extra)
  }

  @Test func theRowsFollowTheGlobalOrderWithTheMainWorktreeFirst() {
    let (harness, extra) = harnessWithThree()
    let all = harness.model.workspace.worktrees

    let rows = harness.model.ordered(all, in: harness.project)
    #expect(rows.map(\.name) == ["main", "aardvark", "feature"])
    #expect(rows.first?.id == harness.main.id, "the trunk holds the top")
    #expect(extra.branch == "aardvark")
  }

  /// The project's override beats the global, and the whole way through:
  /// the setting is written as the form writes it.
  @Test func aProjectsOverrideChangesItsRows() {
    let (harness, _) = harnessWithThree()
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = WorktreeSortOrder.committedNewestFirst
    harness.model.updateSettings(settings, for: harness.project)
    harness.model.lastCommits[harness.feature.id] = Date(timeIntervalSince1970: 2000)

    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name)
        == ["main", "feature", "aardvark"], "the dated branch leads, the undated follows")
  }

  @Test func activeMeansATerminalOrAReportedState() {
    let (harness, extra) = harnessWithThree()
    #expect(!harness.model.isActive(harness.feature.id))
    #expect(!harness.model.isActive(extra.id))

    harness.store.openTab(in: harness.feature.id)
    #expect(harness.model.isActive(harness.feature.id), "a terminal is enough")

    harness.source.send(SessionStateReport(state: .attention, cwd: extra.path.path))
    #expect(harness.model.isActive(extra.id), "so is a state with no terminal")
  }

  @Test func showActiveAtTheTopLiftsTheBusyRow() {
    let (harness, _) = harnessWithThree()
    harness.store.openTab(in: harness.feature.id)
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.showsActiveWorktreesFirst = true
    harness.model.updateSettings(settings, for: harness.project)

    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name)
        == ["main", "feature", "aardvark"], "feature is busy, aardvark only sorts earlier")

    settings.showsActiveWorktreesFirst = false
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name)
        == ["main", "aardvark", "feature"], "off, the name decides again")
  }
}
