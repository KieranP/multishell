import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct WorktreeOrderTests {
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
    _ order: WorktreeOrder, _ worktrees: [Worktree], named: [Worktree.ID: String] = [:],
    active: Set<Worktree.ID> = [], commits: [String: Double] = [:]
  ) -> [String] {
    order.sort(
      worktrees,
      displayName: { named[$0.id] ?? $0.name },
      isActive: { active.contains($0.id) },
      lastCommit: { worktree in
        worktree.branch.flatMap { commits[$0] }.map { epoch.addingTimeInterval($0 * 86_400) }
      }
    ).map { named[$0.id] ?? $0.name }
  }

  @Test func alphabeticalKeepsThePrimaryFirst() {
    let order = WorktreeOrder(order: .alphabetical, activeFirst: false)
    #expect(names(order, worktrees()) == ["main", "alpha", "mango", "zebra"])
  }

  @Test func newestAndOldestAreEachOthersReverseBelowTheTop() {
    let newest = WorktreeOrder(order: .createdNewestFirst, activeFirst: false)
    let oldest = WorktreeOrder(order: .createdOldestFirst, activeFirst: false)
    #expect(names(newest, worktrees()) == ["main", "alpha", "mango", "zebra"])
    #expect(names(oldest, worktrees()) == ["main", "zebra", "mango", "alpha"])
  }

  /// The name the row shows, which is the user's own where they gave one,
  /// not the branch underneath it.
  @Test func alphabeticalGoesByTheDisplayedName() {
    let order = WorktreeOrder(order: .alphabetical, activeFirst: false)
    let list = worktrees()
    let renamed = [list[1].id: "Zzz last"]
    #expect(names(order, list, named: renamed) == ["main", "mango", "zebra", "Zzz last"])
  }

  /// Numbers read as numbers, so wt10 comes after wt9 rather than after
  /// wt1.
  @Test func alphabeticalCountsRunsOfDigitsAsNumbers() {
    let order = WorktreeOrder(order: .alphabetical, activeFirst: false)
    let list = [linked("wt10", daysAfterEpoch: 1), linked("wt9", daysAfterEpoch: 2)]
    #expect(names(order, list) == ["wt9", "wt10"])
  }

  @Test func activeFirstLiftsBusyWorktreesAboveTheRest() {
    let list = worktrees()
    let order = WorktreeOrder(order: .alphabetical, activeFirst: true)
    let busy: Set<Worktree.ID> = [list[0].id, list[3].id]
    #expect(names(order, list, active: busy) == ["main", "mango", "zebra", "alpha"])
  }

  /// The toggle only groups; each group is still in the chosen order.
  @Test func eachGroupKeepsTheChosenOrder() {
    let list = worktrees() + [linked("beta", daysAfterEpoch: 4)]
    let order = WorktreeOrder(order: .createdOldestFirst, activeFirst: true)
    let busy: Set<Worktree.ID> = [list[1].id, list[4].id]
    #expect(names(order, list, active: busy) == ["main", "alpha", "beta", "zebra", "mango"])
  }

  /// Active never outranks the top: the trunk row is what the others are
  /// read against, busy or not.
  @Test func activeFirstNeverMovesTheTop() {
    let list = worktrees()
    let order = WorktreeOrder(order: .alphabetical, activeFirst: true)
    #expect(names(order, list, active: [list[0].id]) == ["main", "zebra", "alpha", "mango"])
  }

  /// A bare repository is git's main worktree, and the trunk is checked out
  /// in a linked one. Both hold the top, the bare one first, as git lists
  /// them.
  @Test func aBareRepositoryKeepsItsTrunkWorktreeSecond() {
    let bare = Worktree(
      path: URL(fileURLWithPath: "/w/acme.git"), projectID: project.id, head: "0", isPrimary: true,
      isBare: true, createdAt: epoch)
    let list = [linked("alpha", daysAfterEpoch: 3), linked("main", daysAfterEpoch: 1), bare]
    let order = WorktreeOrder(order: .alphabetical, activeFirst: false)
    #expect(names(order, list) == ["acme.git", "main", "alpha"])
  }

  /// The project's own trunk, not the guess: a repository whose default
  /// branch is `develop` pins that row, and `main` sorts with the rest.
  @Test func aResolvedTrunkOutranksTheMainMasterGuess() {
    let list = [
      linked("main", daysAfterEpoch: 1), linked("develop", daysAfterEpoch: 2),
      linked("alpha", daysAfterEpoch: 3),
    ]
    let guessed = WorktreeOrder(order: .alphabetical, activeFirst: false)
    #expect(names(guessed, list) == ["main", "alpha", "develop"])
    let resolved = WorktreeOrder(order: .alphabetical, activeFirst: false, trunkBranch: "develop")
    #expect(names(resolved, list) == ["develop", "alpha", "main"])
  }

  /// A detached worktree has no branch to be the trunk, and must not crash
  /// or be pinned by one.
  @Test func aDetachedWorktreeIsNeverTheTrunk() {
    let detached = Worktree(
      path: URL(fileURLWithPath: "/w/t/detached"), projectID: project.id, head: "beefbeefbeef",
      createdAt: epoch.addingTimeInterval(86_400))
    let list = [detached, linked("main", daysAfterEpoch: 2)]
    let order = WorktreeOrder(order: .alphabetical, activeFirst: false)
    #expect(names(order, list) == ["main", "beefbee"])
  }

  /// A directory with no birth time is not the oldest thing in the
  /// repository; it goes last, and the names break the tie among them.
  @Test func worktreesWithNoDateSortLastInBothDateOrders() {
    let list = [
      linked("undated-b", daysAfterEpoch: nil), linked("alpha", daysAfterEpoch: 1),
      linked("undated-a", daysAfterEpoch: nil),
    ]
    for order in [WorktreeSortOrder.createdNewestFirst, .createdOldestFirst] {
      let sorted = names(WorktreeOrder(order: order, activeFirst: false), list)
      #expect(sorted == ["alpha", "undated-a", "undated-b"])
    }
  }

  /// Two worktrees created in the same second keep one order between
  /// renders, whichever way the input happens to arrive.
  @Test func theOrderIsTotal() {
    let a = linked("a", daysAfterEpoch: 1)
    let b = linked("b", daysAfterEpoch: 1)
    let order = WorktreeOrder(order: .createdNewestFirst, activeFirst: false)
    #expect(names(order, [a, b]) == names(order, [b, a]))
  }

  /// The commit dates are runtime state and have nothing to do with when
  /// the directory was made: a worktree cut last week and committed to this
  /// morning is the recently committed one.
  @Test func recentlyCommittedGoesByTheLastCommitNotTheCreationDate() {
    let list = worktrees()
    let commits = ["zebra": 9.0, "alpha": 5.0, "mango": 7.0]
    let newest = WorktreeOrder(order: .committedNewestFirst, activeFirst: false)
    let oldest = WorktreeOrder(order: .committedOldestFirst, activeFirst: false)
    #expect(names(newest, list, commits: commits) == ["main", "zebra", "mango", "alpha"])
    #expect(names(oldest, list, commits: commits) == ["main", "alpha", "mango", "zebra"])
    // Created order disagrees with both, which is the point of the setting.
    #expect(
      names(WorktreeOrder(order: .createdNewestFirst, activeFirst: false), list, commits: commits)
        == ["main", "alpha", "mango", "zebra"])
  }

  /// A branch nobody has a date for — a detached checkout, or a project
  /// whose scan has not run yet — is not the least recently committed thing
  /// in the repository.
  @Test func aBranchWithNoCommitDateSortsLastInBothCommittedOrders() {
    let list = [linked("dated", daysAfterEpoch: 1), linked("undated", daysAfterEpoch: 2)]
    for order in [WorktreeSortOrder.committedNewestFirst, .committedOldestFirst] {
      let sorted = names(
        WorktreeOrder(order: order, activeFirst: false), list, commits: ["dated": 3])
      #expect(sorted == ["dated", "undated"], "\(order)")
    }
  }

  /// Before any scan has answered, every date is missing and the order has
  /// to fall back to something stable rather than to the input's order.
  @Test func withNoDatesAtAllEveryOrderFallsBackToTheName() {
    let list = [linked("zebra", daysAfterEpoch: nil), linked("alpha", daysAfterEpoch: nil)]
    for order in WorktreeSortOrder.allCases {
      #expect(
        names(WorktreeOrder(order: order, activeFirst: false), list) == ["alpha", "zebra"],
        "\(order)")
    }
  }

  /// With no trunk resolved, both guesses are honoured: a repository that
  /// has `main` and `master` checked out pins both rather than picking one
  /// it has no grounds to pick. The first scan settles it.
  @Test func bothGuessedTrunkNamesArePinnedUntilOneIsResolved() {
    let list = [
      linked("alpha", daysAfterEpoch: 1), linked("master", daysAfterEpoch: 2),
      linked("main", daysAfterEpoch: 3),
    ]
    let guessed = WorktreeOrder(order: .alphabetical, activeFirst: false)
    #expect(names(guessed, list) == ["main", "master", "alpha"])

    let resolved = WorktreeOrder(order: .alphabetical, activeFirst: false, trunkBranch: "master")
    #expect(names(resolved, list) == ["master", "alpha", "main"])
  }

  @Test func anEmptyProjectSortsToNothing() {
    for order in WorktreeSortOrder.allCases {
      #expect(names(WorktreeOrder(order: order, activeFirst: true), []).isEmpty, "\(order)")
    }
  }
}

/// The rule reaching the sidebar: which settings win, and what the model
/// counts as active.
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

  /// A terminal open, or a state reported with no terminal at all.
  @Test func activeMeansATerminalOrAReportedState() {
    let (harness, extra) = harnessWithThree()
    #expect(!harness.model.isActive(harness.feature.id))
    #expect(!harness.model.isActive(extra.id))

    harness.store.openTab(in: harness.feature.id)
    #expect(harness.model.isActive(harness.feature.id), "a terminal is enough")

    harness.source.send(SessionStateReport(state: .attention, cwd: extra.path.path))
    #expect(harness.model.isActive(extra.id), "so is a state with no terminal")
  }

  /// The toggle lifts a busy worktree over one that sorts above it, and
  /// still never over the main one.
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

@Suite
@MainActor
struct WorktreeCommitDateLifetimeTests {
  /// Paths are ids, so a project added again gets worktrees with the ids it
  /// had before. Dates read before it left would order its rows until the
  /// first poll answered.
  @Test func removingAProjectForgetsItsCommitDates() {
    let harness = Harness()
    harness.model.lastCommits[harness.main.id] = Date(timeIntervalSince1970: 1000)
    harness.model.lastCommits[harness.feature.id] = Date(timeIntervalSince1970: 2000)

    harness.model.removeProject(harness.project)
    #expect(harness.model.lastCommits.isEmpty)
  }

  /// A project whose default branch went away keeps them: the same call
  /// forgets the merge badges, and losing the dates with them would leave a
  /// trunk-less repository with nothing to order by.
  @Test func losingTheDefaultBranchKeepsTheCommitDates() {
    let harness = Harness()
    harness.model.lastCommits[harness.feature.id] = Date(timeIntervalSince1970: 2000)
    harness.model.mergeStates[harness.feature.id] = .unmerged

    harness.model.forgetMergeStates(of: harness.project.id)
    #expect(harness.model.mergeStates.isEmpty, "the badges go")
    #expect(harness.model.lastCommits.count == 1, "the dates stay")
  }
}

/// The seam the layer tests each miss: a real repository, a real scan, and
/// the rows the sidebar would draw. Everything else about the commit orders
/// is tested with dates put there by hand, so nothing else would notice if
/// the scan's answer never reached the model, or reached it under the wrong
/// key.
@Suite(.serialized)
@MainActor
struct WorktreeOrderOnRealGitTests {
  @Test func theCommitOrderComesOffARealScan() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Cut alphabetically last first, so a name order and a commit order
    // disagree and only the right one can pass.
    for branch in ["zulu", "alpha"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
    }
    // Then commit to zulu, making it the most recently committed. The
    // committer date is set rather than taken from the clock: git prints it
    // in whole seconds, so a repository built and committed to inside one
    // second gives every branch the same date and the order falls back to
    // the name — which is the answer this test is trying to rule out.
    let zulu = try #require(harness.model.workspace.worktrees.first { $0.branch == "zulu" })
    try "work\n".write(
      to: zulu.path.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "."], in: zulu.path)
    _ = try await harness.git.run(
      ["commit", "-q", "-m", "later"], in: zulu.path,
      environment: ["GIT_COMMITTER_DATE": "2030-01-01T00:00:00Z"])

    await harness.model.refreshMergeStates()

    let dated = harness.model.workspace.worktrees.filter { harness.model.lastCommits[$0.id] != nil }
    #expect(dated.count == 3, "every branch got a date, keyed by the worktree the sidebar asks for")

    let all = harness.model.workspace.worktrees
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .committedNewestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "zulu", "alpha"],
      "zulu was committed to last, so it leads")

    settings.worktreeSortOrder = .committedOldestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "alpha", "zulu"])

    settings.worktreeSortOrder = .alphabetical
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "alpha", "zulu"],
      "and the name order disagrees with the newest, so the dates were really read")
  }

  /// The created orders off the same real repository: git makes the
  /// directories, so the birth times are real ones.
  @Test func theCreatedOrderComesOffTheRealDirectories() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Alphabetically first is created first, so the newest-first answer
    // disagrees with the name order. The other way round, two directories
    // sharing a birth time would fall back to the name and give the same
    // rows, and the test would pass without the dates being read at all.
    for branch in ["alpha", "zulu"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
      // A second apart: birth time is only whole-second on some
      // filesystems, and a tie here is what this test exists to rule out.
      try? await Task.sleep(for: .milliseconds(1100))
    }

    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .createdNewestFirst
    harness.model.updateSettings(settings, for: harness.project)
    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "zulu", "alpha"],
      "zulu was created second, and sorts after alpha by name")

    settings.worktreeSortOrder = .createdOldestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "alpha", "zulu"])
  }
}

/// A team ships the order its worktrees list in, the way it ships a worktree
/// path or a hook. Display only, so unlike a hook it needs no trust.
@Suite(.serialized)
@MainActor
struct SharedWorktreeOrderTests {
  @Test func theRepositorysOrderIsUsedUntilTheUserOverridesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Cut alphabetically last first, so the created order and the name
    // order disagree and only the file's answer can pass.
    for branch in ["zulu", "alpha"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
      try? await Task.sleep(for: .milliseconds(1100))
    }
    try #"{ "worktreeSortOrder": "createdOldestFirst" }"#
      .write(
        to: SharedProjectSettings.file(in: harness.project.path), atomically: true, encoding: .utf8)
    await harness.model.refresh(harness.project)

    let all = harness.model.workspace.worktrees
    #expect(harness.model.workspace.worktreeSortOrder == .alphabetical, "the user's global")
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "zulu", "alpha"],
      "the file's order, which the global would have listed the other way")

    // What the form shows for a project overriding neither: the file's
    // value, said to come from the file, so turning the override on seeds
    // what the sidebar was already doing.
    let inherited = harness.model.inherited(
      \.worktreeSortOrder, global: harness.model.workspace.worktreeSortOrder,
      for: harness.project)
    #expect(inherited == InheritedSetting(value: .createdOldestFirst, isFromRepository: true))
    #expect(inherited.caption.contains(SharedProjectSettings.fileName))

    // The user's own choice always wins over the team's.
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .alphabetical
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.ordered(all, in: harness.project).map(\.name) == ["main", "alpha", "zulu"],
      "the user's own order stands over the file's")
  }

  /// Export writes the order out, so a project set up by hand can be handed
  /// to the team without retyping it.
  @Test func exportCarriesTheOrderInForce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .committedNewestFirst
    settings.showsActiveWorktreesFirst = true
    harness.model.updateSettings(settings, for: harness.project)

    harness.model.exportSharedSettings(for: harness.project)

    let written = try #require(try SharedProjectSettings.load(from: harness.project.path))
    #expect(written.worktreeSortOrder == .committedNewestFirst)
    #expect(written.showsActiveWorktreesFirst == true)
    #expect(harness.model.presentedError == nil)
  }
}
