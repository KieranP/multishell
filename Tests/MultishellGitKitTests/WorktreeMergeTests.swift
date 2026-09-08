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
    let scan = await fixture.coordinator.scanBranches(
      of: fixture.project, defaultBranch: override)
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
    try await fixture.commit("work", file: "squashed.txt", content: "a\n")
    _ = try await fixture.git.run(["push", "-q", "-u", "origin", "squashed"], in: path)
    // The merge on the forge squashes the commits and deletes the branch.
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "squashed"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "origin/main")
    #expect(scan.upstreamIsGone("squashed"))
    let states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, scan: scan)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))
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
    let missing = await fixture.coordinator.scanBranches(
      of: fixture.project, defaultBranch: "nowhere")
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

    let scan = await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil)
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
    let scan = await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil)

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
    let scan = await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: nil)

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

    let refs = await WorktreeService(git: fake.runner).branchRefs(Project(path: fake.directory))

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

    let refs = await WorktreeService(git: fake.runner).branchRefs(Project(path: fake.directory))
    let calls =
      (try? String(contentsOf: fake.directory.appendingPathComponent("calls"), encoding: .utf8))
      ?? ""

    #expect(refs.first?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(calls.split(whereSeparator: \.isNewline).count == 1)
  }
}
