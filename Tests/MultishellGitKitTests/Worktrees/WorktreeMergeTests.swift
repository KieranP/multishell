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
    // One commit of the branch's whole tree, as a squash is; two mirroring its own would be a
    // cherry-pick, which `git cherry` answers first. See `WorktreeService.changesAreOnBase`.
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

  /// Carried onto commits it was handed, with none of its own, the branch is as it was the
  /// day it was cut.
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

  /// The same worktree brought up with a bare `git rebase main`: the reflog
  /// reads `rebase (finish)`, as after a replay, and the tip is the trunk's.
  @Test func aBranchRebasedOntoTheTrunkWithNothingOfItsOwnHasNotLanded() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let tree = fixture.root.appendingPathComponent("trees/rebased", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "rebased", tree.path, "HEAD"], in: path)
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.git.run(["rebase", "-q", "main"], in: tree)

    let scan = try await scan(fixture)
    #expect(scan.tip(of: "rebased") == scan.base.tip, "carried up to the trunk")
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, scan: scan)
    #expect(states["rebased"] == .unmerged, "moved is not landed")
  }

  /// `git cherry` skips merge commits, so this prints nothing, which read as every commit
  /// landed; see Docs/design/merged-branch.md.
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

  /// With the upstream gone, `git status` cannot see work held only here, so what the branch
  /// changed is measured against the base; see Docs/design/merged-branch.md.
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

  /// git reads a bare name shared with a path as "both revision and filename" and fails the
  /// read, leaving the branch as never written in; see Docs/design/merged-branch.md.
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

  /// A tag of the branch's name makes `%(refname:short)` answer `heads/x`,
  /// matching no worktree's branch, and a bare name reach the tag instead.
  @Test func aTagSharingABranchsNameChangesNeitherTheListNorTheVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    // The tag sits on the first commit, so judging by it would read the
    // branch as holding nothing of its own.
    _ = try await fixture.git.run(["tag", "release"], in: path)
    _ = try await fixture.git.run(["checkout", "-q", "-b", "release"], in: path)
    try await fixture.commit("work", file: "one.md", content: "one\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    // By refname, or git merges the tag: the ambiguity this is about reaches
    // the setup as readily as the reads.
    _ = try await fixture.git.run(
      ["merge", "-q", "--no-ff", "-m", "merge release", "refs/heads/release"], in: path)

    let service = WorktreeService(git: fixture.git)
    let merged = await service.mergedBranches(into: "main", in: fixture.project)
    #expect(merged?.contains("release") == true, "got \(merged ?? [])")

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["release"], in: fixture.project, scan: scan)
    #expect(states["release"] == .merged(.ancestor, into: "main"))
  }

  @Test func aTagNamedLikeTheLocalBaseDecidesNoVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["tag", "main", "feat"], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)

    #expect(states["feat"] == .unmerged)
  }

  @Test func aTagNamedLikeTheRemoteBaseDecidesNoVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)
    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["tag", "origin/main", "feat"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "origin/main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)

    #expect(states["feat"] == .unmerged)
  }

  /// The same collision on the content read: the two-name form of `git diff` takes the
  /// branch for a path, and the squash-merged branch loses its badge.
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

  /// A bare repository logs no branch creation, so nothing is claimed for a branch with no
  /// reflog; see Docs/design/merged-branch.md. Its first commit is still logged.
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

  /// git answers "no reflog" with success and no output; a failed read taken as that leaves
  /// the branch never written in until it or the trunk next moves.
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

  /// `branch.<name>` config outlives its branch, so a reused name inherits an upstream never
  /// on the remote, which git reports as `[gone]`; see Docs/design/merged-branch.md.
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

  /// `git worktree add -b` cuts the branch at the trunk's tip, an ancestor of the trunk
  /// before a line is written, so ancestry alone would badge it.
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

/// These dates come off the ref list the merge scan already reads, so they cost no process
/// of their own.
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

  /// `git worktree list` gives `feat/tabs`, and the ref list must key it the same, not as
  /// `refs/heads/feat/tabs` or with the first component dropped.
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

/// The ref read carries both the sidebar's commit dates and the badges' tips, and a git that
/// cannot give the first must still give the second.
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

@Suite
struct MergeReadWidthTests {
  @Test func severalProjectsReadTogetherStartNoMoreGitThanOneDoes() async throws {
    let fake = try FakeGit.make(
      """
      case "$1" in
        cherry)
          mkdir -p "$SCRATCH/running"
          touch "$SCRATCH/running/$$"
          ls "$SCRATCH/running" | wc -l >> "$SCRATCH/counts"
          sleep 0.5
          rm "$SCRATCH/running/$$"
          echo "+ 1111111111111111111111111111111111111111" ;;
      esac
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(
      service: WorktreeService(git: fake.runner, settlesNewIndex: false))
    let projects = try ["one", "two"].map { name in
      let path = fake.directory.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
      return Project(path: path)
    }
    let scan = MergeScan(base: DefaultBranch(ref: "main", branch: "main", tip: "a"), refs: [])
    let branches = (1...WorktreeCoordinator.maxConcurrentStatuses).map { "b\($0)" }

    async let first = coordinator.mergeReadings(of: branches, in: projects[0], scan: scan)
    async let second = coordinator.mergeReadings(of: branches, in: projects[1], scan: scan)
    let read = await [first, second]

    #expect(read.map(\.count) == [branches.count, branches.count])
    let counts = try String(
      contentsOf: fake.directory.appendingPathComponent("counts"), encoding: .utf8)
    let peak = counts.split(whereSeparator: \.isNewline).compactMap {
      Int($0.trimmingCharacters(in: .whitespaces))
    }.max()
    #expect(peak.map { $0 <= WorktreeCoordinator.maxConcurrentStatuses } == true, "\(peak ?? 0)")
  }
}
