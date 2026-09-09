import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// The merge check against real repositories: the three ways a branch lands,
/// and the branches it must not claim have landed.
@Suite(.serialized)
struct WorktreeMergeTests {
  /// The fixture with a bare `origin` beside it, so a branch can be pushed
  /// and then deleted on the remote the way a merge does.
  private func withRemote(_ fixture: RepositoryFixture) async throws {
    let origin = fixture.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await fixture.git.run(
      ["clone", "-q", "--bare", fixture.project.path.path, origin.path], in: fixture.root)
    _ = try await fixture.git.run(
      ["remote", "add", "origin", origin.path], in: fixture.project.path)
    _ = try await fixture.git.run(["fetch", "-q", "origin"], in: fixture.project.path)
  }

  private func scan(_ fixture: RepositoryFixture, override: String? = nil) async throws -> MergeScan
  {
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: override))
    return try #require(scan.merges)
  }

  @Test func aBranchMergedWithAMergeCommitIsFoundByAncestry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .merged(.ancestor, into: "main"))
  }

  @Test func aBranchWhosePatchesAreAlreadyOnTheBaseIsFoundByCherry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "rebased"], in: path)
    try await fixture.commit("work", file: "rebased.txt", content: "a\n")
    let commit = try await fixture.head(of: path)
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    // Main moves first, so the cherry-pick lands on a different parent and
    // cannot come out as the very same commit object.
    try await fixture.commit("elsewhere", file: "other.txt", content: "b\n")
    // What a rebase-merge leaves: the same patch, a different commit.
    _ = try await fixture.git.run(["cherry-pick", commit], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, scan: scan)
    #expect(states["rebased"] == .merged(.patchEquivalent, into: "main"))
    // Ancestry alone would have missed it.
    let merged = await WorktreeService(git: fixture.git).mergedBranches(
      into: "main", in: fixture.project)
    #expect(merged?.contains("rebased") == false)
  }

  @Test func aBranchWhoseUpstreamWasDeletedOnTheRemoteReadsAsMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)

    _ = try await fixture.git.run(["checkout", "-q", "-b", "squashed"], in: path)
    // Two commits, so the one the forge squashes them into shares a patch id
    // with neither and `git cherry` cannot answer for the branch.
    try await fixture.commit("work", file: "squashed.txt", content: "a\n")
    try await fixture.commit("more work", file: "squashed-too.txt", content: "b\n")
    _ = try await fixture.git.run(["push", "-q", "-u", "origin", "squashed"], in: path)
    // The merge on the forge squashes the commits onto main and deletes the
    // branch.
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    // One commit carrying the branch's whole tree, which is what a squash is
    // and what says the work landed; see `WorktreeService.changesAreOnBase`.
    // Two commits mirroring the branch's own would be a cherry-pick, and
    // `git cherry` would answer for it before the upstream was ever read.
    try await fixture.commit(
      "squashed work", files: ["squashed.txt": "a\n", "squashed-too.txt": "b\n"])
    _ = try await fixture.git.run(["push", "-q", "origin", "main"], in: path)
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "squashed"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "origin/main")
    #expect(scan.upstreamIsGone("squashed"))
    let states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, scan: scan)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))
  }

  /// A worktree cut before the trunk moved, then brought up to date. The
  /// branch has been carried onto commits it was handed and has none of its
  /// own, which is the day it was cut all over again.
  @Test func aBranchFastForwardedOntoTheTrunkHasNotLanded() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let tree = fixture.root.appendingPathComponent("trees/behind", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "behind", tree.path, "HEAD"], in: path)
    // The trunk moves, and the worktree pulls it in.
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.git.run(["merge", "-q", "--ff-only", "main"], in: tree)

    let scan = try await scan(fixture)
    #expect(scan.tip(of: "behind") == scan.base.tip, "carried up to the trunk")
    let states = await fixture.coordinator.mergeStates(
      of: ["behind"], in: fixture.project, scan: scan)
    #expect(states["behind"] == .unmerged, "moved is not landed")
  }

  /// `git cherry` skips merge commits, so a worktree that has merged the
  /// trunk in and written nothing of its own prints no lines at all. Read as
  /// "every commit landed", that badges a branch that has landed nothing.
  @Test func aBranchWhoseOnlyCommitIsAMergeOfTheTrunkIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let tree = fixture.root.appendingPathComponent("trees/merged-in", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "merged-in", tree.path, "HEAD"], in: path)
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.git.run(
      ["merge", "-q", "--no-ff", "-m", "merge the trunk", "main"], in: tree)

    let scan = try await scan(fixture)
    let cherry = await WorktreeService(git: fixture.git).isPatchEquivalent(
      "merged-in", against: "main", in: fixture.project)
    #expect(cherry == false, "nothing printed is not every patch landed")
    let states = await fixture.coordinator.mergeStates(
      of: ["merged-in"], in: fixture.project, scan: scan)
    #expect(states["merged-in"] == .unmerged)
  }

  /// The badge hides while a worktree holds work that is only there, and for
  /// a gone upstream `git status` cannot see it: there is no upstream left to
  /// be ahead of. So what the branch changed is measured against the base.
  @Test func workCommittedAfterTheSquashLandedTakesTheBadgeBack() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)

    _ = try await fixture.git.run(["checkout", "-q", "-b", "squashed"], in: path)
    try await fixture.commit("work", file: "squashed.txt", content: "a\n")
    try await fixture.commit("more work", file: "squashed-too.txt", content: "b\n")
    _ = try await fixture.git.run(["push", "-q", "-u", "origin", "squashed"], in: path)
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    try await fixture.commit(
      "squashed work", files: ["squashed.txt": "a\n", "squashed-too.txt": "b\n"])
    _ = try await fixture.git.run(["push", "-q", "origin", "main"], in: path)
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "squashed"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let landed = try await scan(fixture)
    var states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, scan: landed)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))

    // Work carried on in the same worktree after the pull request landed.
    _ = try await fixture.git.run(["checkout", "-q", "squashed"], in: path)
    try await fixture.commit("carrying on", file: "squashed.txt", content: "a\nand more\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let after = try await scan(fixture)
    #expect(after.upstreamIsGone("squashed"), "still gone, and still says nothing about this")
    states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, scan: after)
    #expect(states["squashed"] == .unmerged, "this worktree holds the only copy of that")
  }

  /// A branch may share its name with a path in the repository, and git reads
  /// a bare name as "both revision and filename" and fails the whole read. The
  /// reflog answer is lost that way, and with nothing behind it the branch
  /// reads as never written in however much work it landed.
  @Test func aBranchNamedAfterADirectoryIsStillJudgedByItsReflog() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("a directory to collide with", file: "docs/notes.md", content: "a\n")

    _ = try await fixture.git.run(["checkout", "-q", "-b", "docs"], in: path)
    try await fixture.commit("work", file: "docs/one.md", content: "one\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge docs", "docs"], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, scan: scan)

    #expect(states["docs"] == .merged(.ancestor, into: "main"))
  }

  /// The same collision on the content read, where the two-name form of
  /// `git diff` takes the branch for a path: the answer is lost, and with it
  /// the badge a squash-merged branch had earned.
  @Test func aSquashedBranchNamedAfterADirectoryStillReadsAsMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("a directory to collide with", file: "docs/notes.md", content: "a\n")
    try await withRemote(fixture)

    _ = try await fixture.git.run(["checkout", "-q", "-b", "docs"], in: path)
    try await fixture.commit("work", file: "docs/one.md", content: "one\n")
    try await fixture.commit("more work", file: "docs/two.md", content: "two\n")
    _ = try await fixture.git.run(["push", "-q", "-u", "origin", "docs"], in: path)
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    try await fixture.commit(
      "squashed work", files: ["docs/one.md": "one\n", "docs/two.md": "two\n"])
    _ = try await fixture.git.run(["push", "-q", "origin", "main"], in: path)
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "docs"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, scan: scan)

    #expect(states["docs"] == .merged(.upstreamGone, into: "origin/main"))
  }

  /// A bare repository logs no branch creation, so a worktree cut there has
  /// no reflog to be judged by until it is written in, and ancestry alone
  /// cannot tell a branch that landed from one cut behind the trunk. Nothing
  /// is claimed for it rather than guessed from the tips.
  ///
  /// The first commit is logged even there, so a branch that did land still
  /// says so: what goes is the guess, not the badge.
  @Test func aBareRepositoryClaimsNothingForABranchItHasNoReflogFor() async throws {
    let (fixture, checkout) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }
    let bare = fixture.project.path
    let cutFrom = try await fixture.head(of: checkout)
    try await commit("the trunk moves on", file: "later.txt", in: checkout, with: fixture.git)

    let old = fixture.root.appendingPathComponent("trees/old", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "old", old.path, cutFrom], in: bare)

    let service = WorktreeService(git: fixture.git)
    #expect(
      await service.hasWorkOfItsOwn("old", in: fixture.project) == false,
      "a bare repository logs no branch creation, so it has nothing to show for itself")
    let cut = try await scan(fixture)
    #expect(
      cut.tip(of: "old") != cut.base.tip, "cut behind the trunk, which tips alone would badge")
    var states = await fixture.coordinator.mergeStates(
      of: ["old"], in: fixture.project, scan: cut)
    #expect(states["old"] == .unmerged, "nothing to derive it from, so nothing said")

    // A commit is logged even here, so a branch that landed keeps its badge.
    let work = fixture.root.appendingPathComponent("trees/work", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "work", work.path, "main"], in: bare)
    try await commit("work of its own", file: "work.txt", in: work, with: fixture.git)
    _ = try await fixture.git.run(
      ["merge", "-q", "--no-ff", "-m", "merge work", "work"], in: checkout)

    let landed = try await scan(fixture)
    states = await fixture.coordinator.mergeStates(
      of: ["work"], in: fixture.project, scan: landed)
    #expect(states["work"] == .merged(.ancestor, into: "main"))
  }

  /// `RepositoryFixture.commit` writes to the repository itself; a bare
  /// layout's commits are made in one of its worktrees.
  private func commit(
    _ message: String, file: String, in directory: URL, with git: GitRunner
  ) async throws {
    try "\(message)\n".write(
      to: directory.appendingPathComponent(file), atomically: true, encoding: .utf8)
    _ = try await git.run(["add", "."], in: directory)
    _ = try await git.run(["commit", "-q", "-m", message], in: directory)
  }

  /// No reflog is an answer git gives with an empty output and a success; a
  /// read that failed is not that answer, and settling on it would leave the
  /// branch reading as never written in until it or the trunk next moved.
  @Test func aReflogReadThatFailedLeavesTheBranchUnanswered() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        branch\\ --merged*) printf 'main\\nfeat\\n' ;;
        log\\ -g*) exit 128 ;;
      esac
      """)
    defer { fake.tearDown() }
    let scan = MergeScan(
      base: DefaultBranch(ref: "main", branch: "main", tip: "MMM"),
      refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await WorktreeCoordinator(service: WorktreeService(git: fake.runner))
      .mergeStates(of: ["feat"], in: Project(path: fake.directory), scan: scan)

    #expect(states.isEmpty, "no answer, rather than an answer of unmerged")
  }

  /// A read that failed is no verdict: recorded as one it would be pinned to
  /// the tips it was reached at and never asked about again.
  @Test func aPatchReadThatFailedLeavesTheBranchUnanswered() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        branch\\ --merged*) echo main ;;
        cherry*) exit 128 ;;
      esac
      """)
    defer { fake.tearDown() }
    let scan = MergeScan(
      base: DefaultBranch(ref: "main", branch: "main", tip: "MMM"),
      refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await WorktreeCoordinator(service: WorktreeService(git: fake.runner))
      .mergeStates(of: ["feat"], in: Project(path: fake.directory), scan: scan)

    #expect(states.isEmpty, "no answer, rather than an answer of unmerged")
  }

  /// The same `[gone]`, with nothing behind it. `branch.<name>` config
  /// outlives the branch it names, so a name used before hands the branch cut
  /// under it an upstream that was never on the remote, and git reports that
  /// in the same words as one deleted on a merge. The badge showed on the
  /// first commit, when ancestry stopped answering for the branch and the
  /// gone upstream was all that was left.
  @Test func aBranchWhoseUpstreamWasNeverThereIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)

    // What the branch that had the name before left behind.
    _ = try await fixture.git.run(["config", "branch.reused.remote", "origin"], in: path)
    _ = try await fixture.git.run(["config", "branch.reused.merge", "refs/heads/reused"], in: path)
    let tree = fixture.root.appendingPathComponent("trees/reused", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "reused", tree.path, "HEAD"], in: path)

    let cut = try await scan(fixture)
    #expect(cut.upstreamIsGone("reused"), "git cannot tell the two apart")
    var states = await fixture.coordinator.mergeStates(
      of: ["reused"], in: fixture.project, scan: cut)
    #expect(states["reused"] == .unmerged, "cut from the trunk and not written in")

    _ = try await fixture.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: tree)
    let committed = try await scan(fixture)
    states = await fixture.coordinator.mergeStates(
      of: ["reused"], in: fixture.project, scan: committed)
    #expect(states["reused"] == .unmerged, "a first commit is not a merge")
  }

  /// `git worktree add -b` cuts the branch at the trunk's own tip, which
  /// makes it an ancestor of the trunk before a line has been written in
  /// it. Ancestry alone would badge it.
  @Test func aBranchJustCutForANewWorktreeIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("second", file: "b.txt", content: "b\n")
    let tree = fixture.root.appendingPathComponent("trees/fresh", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "fresh", tree.path, "HEAD"], in: path)

    let scan = try await scan(fixture)
    // git itself calls it merged, which is the whole trap.
    let merged = await WorktreeService(git: fixture.git).mergedBranches(
      into: scan.base.ref, in: fixture.project)
    #expect(merged?.contains("fresh") == true)

    let states = await fixture.coordinator.mergeStates(
      of: ["fresh"], in: fixture.project, scan: scan)
    #expect(states["fresh"] == .unmerged)
  }

  /// The same branch once it has been committed to and fast-forwarded in:
  /// its tip is the trunk's tip again, but its reflog says it moved.
  @Test func aBranchFastForwardedIntoTheTrunkIsStillMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let tree = fixture.root.appendingPathComponent("trees/ff", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "ff", tree.path, "HEAD"], in: path)
    try "a\n".write(to: tree.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    _ = try await fixture.git.run(["add", "."], in: tree)
    _ = try await fixture.git.run(["commit", "-q", "-m", "work"], in: tree)
    _ = try await fixture.git.run(["merge", "-q", "--ff-only", "ff"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.tip(of: "ff") == scan.base.tip, "indistinguishable from a fresh branch by tips")
    let states = await fixture.coordinator.mergeStates(of: ["ff"], in: fixture.project, scan: scan)
    #expect(states["ff"] == .merged(.ancestor, into: "main"))
  }

  @Test func aBranchWithWorkOfItsOwnIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .unmerged)
  }

  @Test func aBranchThatLandedAndThenMovedAgainIsUnmergedOnceMore() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)
    _ = try await fixture.git.run(["checkout", "-q", "feat"], in: path)
    try await fixture.commit("more", file: "feat.txt", content: "b\n")

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .unmerged)
  }

  @Test func theDefaultBranchIsTheRemotesWhereThereIsOneAndTheUsersWhereTheySaid()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)
    _ = try await fixture.git.run(["checkout", "-q", "-b", "develop"], in: path)
    try await fixture.commit("dev", file: "dev.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    // The clone recorded origin/HEAD, and the remote wins over a local main
    // that a pull has not caught up with.
    let detected = try await scan(fixture)
    #expect(detected.base.ref == "origin/main")
    #expect(detected.base.branch == "main")

    // The user's own name, which exists only locally.
    let overridden = try await scan(fixture, override: "develop")
    #expect(overridden.base.ref == "develop")

    // A name that is nowhere: no base, so nothing is badged.
    let missing = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: "nowhere"))
    #expect(missing.merges == nil)
    #expect(missing.lastCommits["main"] != nil, "the dates come back with no base to measure")
  }

  @Test func aScanOfNoBranchesAsksGitNothingAndAnswersNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(of: [], in: fixture.project, scan: scan)
    #expect(states.isEmpty)
  }

  @Test func onlyALinkedWorktreeOnABranchOfItsOwnCanBeBadged() {
    let main = Worktree(
      path: URL(fileURLWithPath: "/r"), projectID: "/r", head: "a",
      branch: "main", isPrimary: true)
    let trunk = Worktree(
      path: URL(fileURLWithPath: "/t/main"), projectID: "/r", head: "a",
      branch: "main")
    let feat = Worktree(
      path: URL(fileURLWithPath: "/t/feat"), projectID: "/r", head: "a",
      branch: "feat")
    let detached = Worktree(path: URL(fileURLWithPath: "/t/d"), projectID: "/r", head: "abc1234")
    let bare = Worktree(
      path: URL(fileURLWithPath: "/r.git"), projectID: "/r", head: "a",
      isBare: true)

    #expect(WorktreeMergeState.applies(to: feat, base: "main"))
    // The main worktree cannot be removed, so "safe to remove" cannot apply.
    #expect(!WorktreeMergeState.applies(to: main, base: "main"))
    // The trunk's own checkout in a bare layout: not merged into itself.
    #expect(!WorktreeMergeState.applies(to: trunk, base: "main"))
    #expect(!WorktreeMergeState.applies(to: detached, base: "main"))
    #expect(!WorktreeMergeState.applies(to: bare, base: "main"))
  }
}

/// The dates the sidebar's recently-committed orders go by. They come off the
/// ref list the merge scan already reads, so they cost no process of their
/// own.
@Suite(.serialized)
struct BranchCommitDateTests {
  @Test func eachLocalBranchCarriesItsLastCommitTime() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("later", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil))
    let main = try #require(scan.lastCommits["main"])
    let feat = try #require(scan.lastCommits["feat"])

    #expect(main <= feat, "feat was committed to after main was left behind")
    #expect(abs(feat.timeIntervalSinceNow) < 300, "a real commit time, not the epoch")
    #expect(scan.lastCommits["origin/main"] == nil, "local branches only")
  }

  /// The dates are looked up by the branch a worktree reports, so the two
  /// spellings have to agree: `git worktree list` gives `feat/tabs` and the
  /// ref list must key it the same way, not as `refs/heads/feat/tabs` or
  /// with the first component dropped.
  @Test func aBranchWithSlashesIsKeyedTheWayAWorktreeNamesIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.create(
      branch: "feat/tabs", in: fixture.project,
      settings: WorktreeSettings(worktreeDirectory: "../trees"))

    let listed = try await WorktreeService(git: fixture.git).list(fixture.project)
    let worktree = try #require(
      listed.first { $0.path.standardizedFileURL == path.standardizedFileURL })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil))

    #expect(worktree.branch == "feat/tabs")
    #expect(worktree.branch.flatMap { scan.lastCommits[$0] } != nil, "the lookup finds it")
  }

  /// A worktree's branch is what the app looks the date up by, so a
  /// detached checkout has none rather than borrowing another branch's.
  @Test func aDetachedWorktreeHasNoBranchToDate() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let head = try await fixture.head(of: fixture.project.path)
    let path = fixture.root.appendingPathComponent("detached", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "--detach", path.path, head], in: fixture.project.path)

    let listed = try await WorktreeService(git: fixture.git).list(fixture.project)
    let detached = try #require(listed.first { $0.path.lastPathComponent == "detached" })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil))

    #expect(detached.branch == nil)
    #expect(detached.branch.flatMap { scan.lastCommits[$0] } == nil)
    #expect(detached.createdAt != nil, "the directory still has a creation date")
  }
}

/// The ref read carries the commit dates the sidebar orders by and the tips
/// the merged badges are measured from. A git that cannot do the first must
/// still answer the second.
@Suite
struct BranchRefFallbackTests {
  @Test func aGitTooOldForTheDateAtomStillAnswersWithTheRest() async throws {
    // Fails any query naming committerdate, as git does for an unknown
    // format atom, and answers the rest.
    let fake = try FakeGit.make(
      """
      case "$*" in
        *committerdate*) echo "fatal: unknown field name: committerdate:unix" >&2; exit 128 ;;
      esac
      printf 'refs/heads/main\\t111\\t\\t\\t\\n'
      """)
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeService(git: fake.runner).branchRefs(Project(path: fake.directory)))

    #expect(refs.map(\.fullName) == ["refs/heads/main"], "the badges still have their tips")
    #expect(refs.first?.tip == "111")
    #expect(refs.first?.committedAt == nil, "the order loses its dates, and only those")
  }

  /// The retry is only for a failure: a git that answers the first query is
  /// asked once.
  @Test func aGitThatAnswersIsAskedOnce() async throws {
    let fake = try FakeGit.make(
      """
      echo x >> "$SCRATCH/calls"
      printf 'refs/heads/main\\t111\\t\\t\\t\\t1700000000\\n'
      """)
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeService(git: fake.runner).branchRefs(Project(path: fake.directory)))
    let calls =
      (try? String(contentsOf: fake.directory.appendingPathComponent("calls"), encoding: .utf8))
      ?? ""

    #expect(refs.first?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(calls.split(whereSeparator: \.isNewline).count == 1)
  }
}
