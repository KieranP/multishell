import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct WorktreeSortRuleTests {
  private let project = Project(path: URL(fileURLWithPath: "/w/acme"))
  private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

  /// `main` is the primary, then three linked worktrees created a day
  /// apart in an order that is neither alphabetical nor chronological.
  private func worktrees() -> [Worktree] {
    [
      linked("zebra", daysAfterEpoch: 1),
      linked("alpha", daysAfterEpoch: 3),
      primary("main"),
      linked("mango", daysAfterEpoch: 2),
    ]
  }

  private func primary(_ branch: String) -> Worktree {
    Worktree(
      path: project.path, projectID: project.id, head: "0", branch: branch, isPrimary: true,
      createdAt: epoch)
  }

  private func linked(_ branch: String, daysAfterEpoch days: Double?) -> Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/w/t/\(branch)"), projectID: project.id, head: "0",
      branch: branch,
      createdAt: days.map { epoch.addingTimeInterval($0 * 86_400) })
  }

  private func names(
    _ rule: WorktreeSortRule, _ worktrees: [Worktree], named: [Worktree.ID: String] = [:],
    active: Set<Worktree.ID> = [], commits: [String: Double] = [:]
  ) -> [String] {
    let keys = rule.keys(
      worktrees,
      displayName: { named[$0.id] ?? $0.name },
      isActive: { active.contains($0.id) },
      lastCommit: { worktree in
        worktree.branch.flatMap { commits[$0] }.map { epoch.addingTimeInterval($0 * 86_400) }
      })
    return rule.sorted(keys).map { named[$0.id] ?? $0.name }
  }

  @Test func alphabeticalKeepsThePrimaryFirst() {
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    #expect(names(rule, worktrees()) == ["main", "alpha", "mango", "zebra"])
  }

  @Test func newestAndOldestAreEachOthersReverseBelowTheTop() {
    let newest = WorktreeSortRule(sortOrder: .createdNewestFirst, showsActiveFirst: false)
    let oldest = WorktreeSortRule(sortOrder: .createdOldestFirst, showsActiveFirst: false)
    #expect(names(newest, worktrees()) == ["main", "alpha", "mango", "zebra"])
    #expect(names(oldest, worktrees()) == ["main", "zebra", "mango", "alpha"])
  }

  /// The name the row shows, which is the user's own where they gave one,
  /// not the branch underneath it.
  @Test func alphabeticalGoesByTheDisplayedName() {
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    let list = worktrees()
    let renamed = [list[1].id: "Zzz last"]
    #expect(names(rule, list, named: renamed) == ["main", "mango", "zebra", "Zzz last"])
  }

  @Test func alphabeticalCountsRunsOfDigitsAsNumbers() {
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    let list = [linked("wt10", daysAfterEpoch: 1), linked("wt9", daysAfterEpoch: 2)]
    #expect(names(rule, list) == ["wt9", "wt10"])
  }

  @Test func activeFirstLiftsBusyWorktreesAboveTheRest() {
    let list = worktrees()
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: true)
    let busy: Set<Worktree.ID> = [list[0].id, list[3].id]
    #expect(names(rule, list, active: busy) == ["main", "mango", "zebra", "alpha"])
  }

  @Test func eachGroupKeepsTheChosenOrder() {
    let list = worktrees() + [linked("beta", daysAfterEpoch: 4)]
    let rule = WorktreeSortRule(sortOrder: .createdOldestFirst, showsActiveFirst: true)
    let busy: Set<Worktree.ID> = [list[1].id, list[4].id]
    #expect(names(rule, list, active: busy) == ["main", "alpha", "beta", "zebra", "mango"])
  }

  /// Active never outranks the top: the trunk row is what the others are
  /// read against, busy or not.
  @Test func activeFirstNeverMovesTheTop() {
    let list = worktrees()
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: true)
    #expect(names(rule, list, active: [list[0].id]) == ["main", "zebra", "alpha", "mango"])
  }

  /// A bare repository is git's main worktree and the trunk sits in a linked one; both
  /// hold the top, the bare one first, as git lists them.
  @Test func aBareRepositoryKeepsItsTrunkWorktreeSecond() {
    let bare = Worktree(
      path: URL(fileURLWithPath: "/w/acme.git"), projectID: project.id, head: "0", isPrimary: true,
      isBare: true, createdAt: epoch)
    let list = [linked("alpha", daysAfterEpoch: 3), linked("main", daysAfterEpoch: 1), bare]
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    #expect(names(rule, list) == ["acme.git", "main", "alpha"])
  }

  @Test func aResolvedTrunkOutranksTheMainMasterGuess() {
    let list = [
      linked("main", daysAfterEpoch: 1), linked("develop", daysAfterEpoch: 2),
      linked("alpha", daysAfterEpoch: 3),
    ]
    let guessed = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    #expect(names(guessed, list) == ["main", "alpha", "develop"])
    let resolved = WorktreeSortRule(
      sortOrder: .alphabetical, showsActiveFirst: false, trunkBranch: "develop")
    #expect(names(resolved, list) == ["develop", "alpha", "main"])
  }

  @Test func aDetachedWorktreeIsNeverTheTrunk() {
    let detached = Worktree(
      path: URL(fileURLWithPath: "/w/t/detached"), projectID: project.id, head: "beefbeefbeef",
      createdAt: epoch.addingTimeInterval(86_400))
    let list = [detached, linked("main", daysAfterEpoch: 2)]
    let rule = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    #expect(names(rule, list) == ["main", "beefbee"])
  }

  /// A directory with no birth time is not the oldest thing in the
  /// repository; it goes last, and the names break the tie among them.
  @Test func worktreesWithNoDateSortLastInBothDateOrders() {
    let list = [
      linked("undated-b", daysAfterEpoch: nil), linked("alpha", daysAfterEpoch: 1),
      linked("undated-a", daysAfterEpoch: nil),
    ]
    for order in [WorktreeSortOrder.createdNewestFirst, .createdOldestFirst] {
      let sorted = names(WorktreeSortRule(sortOrder: order, showsActiveFirst: false), list)
      #expect(sorted == ["alpha", "undated-a", "undated-b"])
    }
  }

  @Test func twoWorktreesCreatedTogetherSortTheSameWhicheverArrivesFirst() {
    let a = linked("a", daysAfterEpoch: 1)
    let b = linked("b", daysAfterEpoch: 1)
    let rule = WorktreeSortRule(sortOrder: .createdNewestFirst, showsActiveFirst: false)
    #expect(names(rule, [a, b]) == names(rule, [b, a]))
  }

  /// Commit dates are runtime state, unrelated to when the directory was made: a worktree
  /// cut last week and committed to this morning is the recently committed one.
  @Test func recentlyCommittedGoesByTheLastCommitNotTheCreationDate() {
    let list = worktrees()
    let commits = ["zebra": 9.0, "alpha": 5.0, "mango": 7.0]
    let newest = WorktreeSortRule(sortOrder: .committedNewestFirst, showsActiveFirst: false)
    let oldest = WorktreeSortRule(sortOrder: .committedOldestFirst, showsActiveFirst: false)
    #expect(names(newest, list, commits: commits) == ["main", "zebra", "mango", "alpha"])
    #expect(names(oldest, list, commits: commits) == ["main", "alpha", "mango", "zebra"])
    // Created order disagrees with both, which is the point of the setting.
    #expect(
      names(
        WorktreeSortRule(sortOrder: .createdNewestFirst, showsActiveFirst: false), list,
        commits: commits)
        == ["main", "alpha", "mango", "zebra"])
  }

  /// A branch with no date, a detached checkout or a project not yet scanned, is not the
  /// least recently committed thing in the repository.
  @Test func aBranchWithNoCommitDateSortsLastInBothCommittedOrders() {
    let list = [linked("dated", daysAfterEpoch: 1), linked("undated", daysAfterEpoch: 2)]
    for order in [WorktreeSortOrder.committedNewestFirst, .committedOldestFirst] {
      let sorted = names(
        WorktreeSortRule(sortOrder: order, showsActiveFirst: false), list, commits: ["dated": 3])
      #expect(sorted == ["dated", "undated"], "\(order)")
    }
  }

  /// Before any scan has answered, every date is missing and the order has
  /// to fall back to something stable rather than to the input's order.
  @Test func withNoDatesAtAllEveryOrderFallsBackToTheName() {
    let list = [linked("zebra", daysAfterEpoch: nil), linked("alpha", daysAfterEpoch: nil)]
    for order in WorktreeSortOrder.allCases {
      #expect(
        names(WorktreeSortRule(sortOrder: order, showsActiveFirst: false), list) == [
          "alpha", "zebra",
        ],
        "\(order)")
    }
  }

  /// With no trunk resolved, `main` and `master` are both pinned, there being no grounds
  /// to pick one; the first scan settles it.
  @Test func bothGuessedTrunkNamesArePinnedUntilOneIsResolved() {
    let list = [
      linked("alpha", daysAfterEpoch: 1), linked("master", daysAfterEpoch: 2),
      linked("main", daysAfterEpoch: 3),
    ]
    let guessed = WorktreeSortRule(sortOrder: .alphabetical, showsActiveFirst: false)
    #expect(names(guessed, list) == ["main", "master", "alpha"])

    let resolved = WorktreeSortRule(
      sortOrder: .alphabetical, showsActiveFirst: false, trunkBranch: "master")
    #expect(names(resolved, list) == ["master", "alpha", "main"])
  }

  @Test func anEmptyProjectSortsToNothing() {
    for order in WorktreeSortOrder.allCases {
      #expect(
        names(WorktreeSortRule(sortOrder: order, showsActiveFirst: true), []).isEmpty, "\(order)")
    }
  }
}
