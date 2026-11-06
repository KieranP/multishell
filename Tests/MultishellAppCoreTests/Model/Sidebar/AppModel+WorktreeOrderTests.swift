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
      projectID: harness.project.id,
      head: "c",
      branch: "aardvark",
    )
    harness.store.replaceWorktrees(
      [harness.main, harness.feature, extra],
      forProject: harness.project.id,
    )
    return (harness, extra)
  }

  @Test func theRowsFollowTheGlobalOrderWithTheMainWorktreeFirst() {
    let (harness, _) = harnessWithThreeWorktrees()
    let all = harness.model.workspace.worktrees

    let rows = harness.model.orderedWorktrees(
      all,
      in: harness.project,
      sessions: harness.model.sessionIDsByWorktree,
    )
    #expect(rows.map(\.name) == ["main", "aardvark", "feature"])
    #expect(rows.first?.id == harness.main.id, "the trunk holds the top")
  }

  @Test func hiddenRowsAreSortedByTheSameRuleAndSplitOffTheRest() {
    let (harness, extra) = harnessWithThreeWorktrees()
    harness.model.setHidden(true, worktree: harness.feature)
    harness.model.setHidden(true, worktree: extra)
    let entry = harness.model.sidebarEntries[0]

    let rows = harness.model.orderedWorktrees(
      of: entry,
      sessions: harness.model.sessionIDsByWorktree,
    )

    #expect(rows.worktrees.map(\.name) == ["main"])
    #expect(rows.hiddenWorktrees.map(\.name) == ["aardvark", "feature"])
  }

  @Test func theSidebarAndTheCommandLineShareOneSortOfAProjectWithHiddenRows() {
    let (harness, _) = harnessWithThreeWorktrees()
    harness.model.setHidden(true, worktree: harness.feature)
    let entry = harness.model.sidebarEntries[0]
    let sessions = harness.model.sessionIDsByWorktree
    let before = harness.model.worktreeSortCache.sortCount

    _ = harness.model.orderedWorktrees(of: entry, sessions: sessions)
    _ = harness.model.orderedWorktrees(of: entry, sessions: sessions)

    #expect(harness.model.worktreeSortCache.sortCount == before + 1)
  }

  @Test func aProjectWithNothingHiddenOrdersEveryRowAndHidesNone() {
    let (harness, _) = harnessWithThreeWorktrees()
    let entry = harness.model.sidebarEntries[0]

    let rows = harness.model.orderedWorktrees(
      of: entry,
      sessions: harness.model.sessionIDsByWorktree,
    )

    #expect(rows.worktrees.map(\.name) == ["main", "aardvark", "feature"])
    #expect(rows.hiddenWorktrees.isEmpty)
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
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name)
        == ["main", "feature", "aardvark"],
      "the dated branch leads, the undated follows",
    )
  }

  @Test func activeMeansATerminalOrAReportedState() {
    let (harness, extra) = harnessWithThreeWorktrees()
    func isActive(_ id: Worktree.ID) -> Bool {
      harness.model.sessionStates.isActive(
        worktree: id,
        sessions: harness.model.sessionIDsByWorktree[id],
      )
    }
    #expect(!isActive(harness.feature.id))
    #expect(!isActive(extra.id))

    harness.store.openTab(in: harness.feature.id)
    #expect(isActive(harness.feature.id), "a terminal is enough")

    harness.messageSource.send(
      SessionStateReport(state: .attention, workingDirectory: extra.path.path)
    )
    #expect(isActive(extra.id), "so is a state with no terminal")
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
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name)
        == ["main", "feature", "aardvark"],
      "feature is busy, aardvark only sorts earlier",
    )

    settings.showsActiveWorktreesFirst = false
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name)
        == ["main", "aardvark", "feature"],
      "off, the name decides again",
    )
  }
}
