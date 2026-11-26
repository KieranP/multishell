import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

struct WorktreeRowGitBadgeTests {
  @Test func aStopTakesTheCountsPlace() throws {
    var status = WorktreeStatus()
    status.unfinishedUpdate = .rebase
    status.conflicted = 1
    status.unstaged = 3

    let badge = try #require(WorktreeRowGitBadge(status))

    #expect(badge.summary == "Rebasing · 1 conflict")
    guard case .unfinishedUpdate(_, let help) = badge else {
      Issue.record("a stop drew its counts")
      return
    }
    #expect(help == status.unfinishedUpdateHelp)
  }

  @Test func aCrowdedRowKeepsAStopAsAnAlertButDropsTheCounts() throws {
    var stopped = WorktreeStatus()
    stopped.unfinishedUpdate = .merge
    var changed = WorktreeStatus()
    changed.unstaged = 1
    changed.changedFiles = 1
    let stop = try #require(WorktreeRowGitBadge(stopped))
    let counts = try #require(WorktreeRowGitBadge(changed))

    #expect(stop.crowdedAlert(in: .alertsOnly) == "Merging")
    #expect(stop.crowdedAlert(in: .withoutServices) == nil, "the row shows the words")
    #expect(counts.crowdedAlert(in: .alertsOnly) == nil)
  }

  @Test func changesWithNoStopShowTheCounts() {
    var status = WorktreeStatus()
    status.unstaged = 2
    status.changedFiles = 2

    #expect(WorktreeRowGitBadge(status) == .counts(status))
  }

  @Test func aCleanRowInSyncOrOneNotReadShowsNothing() {
    #expect(WorktreeRowGitBadge(WorktreeStatus()) == nil)
    #expect(WorktreeRowGitBadge(nil) == nil)
  }
}
