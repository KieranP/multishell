import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// The merge check against real repositories: the three ways a branch lands,
/// and the branches it must not claim have landed.
@Suite(.serialized)
struct WorktreeCoordinatorMergesTests {
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

  private func mergeInputs(
    _ fixture: RepositoryFixture, override: String? = nil
  ) async throws -> MergeInputs {
    let branches = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: override))
    return try #require(branches.mergeInputs)
  }

  @Test func aBranchMergedWithAMergeCommitIsFoundByAncestry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.base.shortName == "main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, inputs: inputs)
    #expect(states["rebased"] == .merged(.patchEquivalent, into: "main"))
    // Ancestry alone would have missed it.
    let merged = await WorktreeGit(runner: fixture.git).mergedBranches(
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
    // cherry-pick, which `git cherry` answers first. See `WorktreeGit.changesAreOnBase`.
    try await fixture.commit(
      "squashed work", files: ["squashed.txt": "a\n", "squashed-too.txt": "b\n"])
    _ = try await fixture.git.run(["push", "-q", "origin", "main"], in: path)
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "squashed"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.base.shortName == "origin/main")
    #expect(inputs.upstreamIsGone("squashed"))
    let states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.tip(of: "behind") == inputs.base.tip, "carried up to the trunk")
    let states = await fixture.coordinator.mergeStates(
      of: ["behind"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.tip(of: "rebased") == inputs.base.tip, "carried up to the trunk")
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    let cherry = await WorktreeGit(runner: fixture.git).isPatchEquivalent(
      "merged-in", against: "main", in: fixture.project)
    #expect(cherry == false, "nothing printed is not every patch landed")
    let states = await fixture.coordinator.mergeStates(
      of: ["merged-in"], in: fixture.project, inputs: inputs)
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

    let landed = try await mergeInputs(fixture)
    var states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, inputs: landed)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))

    // Work carried on in the same worktree after the pull request landed.
    _ = try await fixture.git.run(["checkout", "-q", "squashed"], in: path)
    try await fixture.commit("carrying on", file: "squashed.txt", content: "a\nand more\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let after = try await mergeInputs(fixture)
    #expect(after.upstreamIsGone("squashed"), "still gone, and still says nothing about this")
    states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, inputs: after)
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

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, inputs: inputs)

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

    let worktreeGit = WorktreeGit(runner: fixture.git)
    let merged = await worktreeGit.mergedBranches(into: "main", in: fixture.project)
    #expect(merged?.contains("release") == true, "got \(merged ?? [])")

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["release"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)

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

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.base.shortName == "origin/main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)

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

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, inputs: inputs)

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

    let worktreeGit = WorktreeGit(runner: fixture.git)
    #expect(
      await worktreeGit.hasWorkOfItsOwn("old", in: fixture.project) == false,
      "a bare repository logs no branch creation, so it has nothing to show for itself")
    let cut = try await mergeInputs(fixture)
    #expect(
      cut.tip(of: "old") != cut.base.tip, "cut behind the trunk, which tips alone would badge")
    var states = await fixture.coordinator.mergeStates(
      of: ["old"], in: fixture.project, inputs: cut)
    #expect(states["old"] == .unmerged, "nothing to derive it from, so nothing said")

    // A commit is logged even here, so a branch that landed keeps its badge.
    let work = fixture.root.appendingPathComponent("trees/work", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "work", work.path, "main"], in: bare)
    try await commit("work of its own", file: "work.txt", in: work, with: fixture.git)
    _ = try await fixture.git.run(
      ["merge", "-q", "--no-ff", "-m", "merge work", "work"], in: checkout)

    let landed = try await mergeInputs(fixture)
    states = await fixture.coordinator.mergeStates(
      of: ["work"], in: fixture.project, inputs: landed)
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
    let inputs = MergeInputs(
      base: DefaultBranch(shortName: "main", branchName: "main", tip: "MMM", fullName: "main"),
      refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await WorktreeCoordinator(git: WorktreeGit(runner: fake.runner))
      .mergeStates(of: ["feat"], in: Project(path: fake.directory), inputs: inputs)

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
    let inputs = MergeInputs(
      base: DefaultBranch(shortName: "main", branchName: "main", tip: "MMM", fullName: "main"),
      refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await WorktreeCoordinator(git: WorktreeGit(runner: fake.runner))
      .mergeStates(of: ["feat"], in: Project(path: fake.directory), inputs: inputs)

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

    let cut = try await mergeInputs(fixture)
    #expect(cut.upstreamIsGone("reused"), "git cannot tell the two apart")
    var states = await fixture.coordinator.mergeStates(
      of: ["reused"], in: fixture.project, inputs: cut)
    #expect(states["reused"] == .unmerged, "cut from the trunk and not written in")

    _ = try await fixture.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: tree)
    let committed = try await mergeInputs(fixture)
    states = await fixture.coordinator.mergeStates(
      of: ["reused"], in: fixture.project, inputs: committed)
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

    let inputs = try await mergeInputs(fixture)
    // git itself calls it merged, which is the whole trap.
    let merged = await WorktreeGit(runner: fixture.git).mergedBranches(
      into: inputs.base.shortName, in: fixture.project)
    #expect(merged?.contains("fresh") == true)

    let states = await fixture.coordinator.mergeStates(
      of: ["fresh"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    #expect(
      inputs.tip(of: "ff") == inputs.base.tip, "indistinguishable from a fresh branch by tips")
    let states = await fixture.coordinator.mergeStates(
      of: ["ff"], in: fixture.project, inputs: inputs)
    #expect(states["ff"] == .merged(.ancestor, into: "main"))
  }

  @Test func aBranchWithWorkOfItsOwnIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)
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

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)
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
    let detected = try await mergeInputs(fixture)
    #expect(detected.base.shortName == "origin/main")
    #expect(detected.base.branchName == "main")

    // The user's own name, which exists only locally.
    let overridden = try await mergeInputs(fixture, override: "develop")
    #expect(overridden.base.shortName == "develop")

    // A name that is nowhere: no base, so nothing is badged.
    let missing = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranch: "nowhere"))
    #expect(missing.mergeInputs == nil)
    #expect(missing.lastCommits["main"] != nil, "the dates come back with no base to measure")
  }

  @Test func aScanOfNoBranchesAsksGitNothingAndAnswersNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(of: [], in: fixture.project, inputs: inputs)
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
