import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorMergesTests {
  func addOrigin(to fixture: RepositoryFixture) async throws {
    try await TestRepository.addOrigin(
      to: fixture.project.path, in: fixture.root, using: fixture.runner)
  }

  func mergeInputs(
    _ fixture: RepositoryFixture, override: String? = nil
  ) async throws -> MergeInputs {
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: override))
    return try #require(scan.mergeInputs)
  }

  /// Two commits, so the one the forge squashes them into shares a patch id with neither and
  /// `git cherry` cannot answer. The squash is one commit of the whole tree, then the branch goes.
  func squashMergeOnTheRemote(
    _ branch: String, work: [(file: String, content: String)], in fixture: RepositoryFixture
  ) async throws {
    let path = fixture.project.path
    _ = try await fixture.runner.run(["checkout", "-q", "-b", branch], in: path)
    for (index, change) in work.enumerated() {
      try await fixture.commit(
        index == 0 ? "work" : "more work", file: change.file, content: change.content)
    }
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", branch], in: path)
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)
    try await TestRepository.squashMergeOnTheRemote(
      branch,
      files: Dictionary(work.map { ($0.file, $0.content) }, uniquingKeysWith: { _, last in last }),
      in: path, using: fixture.runner)
  }

  func stubInputs(baseTip: String, refs: [BranchRef] = []) -> MergeInputs {
    MergeInputs(
      base: DefaultBranch(
        shortName: "main", nameWithoutRemote: "main", tip: baseTip, fullName: "main"),
      branches: BranchRef.localBranchesByName(refs))
  }

  @Test func aBranchMergedWithAMergeCommitIsFoundByAncestry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)

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

    _ = try await fixture.runner.run(["checkout", "-q", "-b", "rebased"], in: path)
    try await fixture.commit("work", file: "rebased.txt", content: "a\n")
    let commit = try await fixture.head(of: path)
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)
    // Main moves first, so the cherry-pick lands on a different parent and
    // cannot come out as the very same commit object.
    try await fixture.commit("elsewhere", file: "other.txt", content: "b\n")
    // What a rebase-merge leaves: the same patch, a different commit.
    _ = try await fixture.runner.run(["cherry-pick", commit], in: path)

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, inputs: inputs)
    #expect(states["rebased"] == .merged(.patchEquivalent, into: "main"))
    // Ancestry alone would have missed it.
    let merged = await WorktreeGit(runner: fixture.runner).mergedBranches(
      into: "main", in: fixture.project)
    #expect(merged?.contains("rebased") == false)
  }

  @Test func aBranchWhoseUpstreamWasDeletedOnTheRemoteReadsAsMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await addOrigin(to: fixture)

    try await squashMergeOnTheRemote(
      "squashed", work: [("squashed.txt", "a\n"), ("squashed-too.txt", "b\n")], in: fixture)

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
    let tree = try await fixture.addWorktree(onNewBranch: "behind")
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.runner.run(["merge", "-q", "--ff-only", "main"], in: tree)

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
    let tree = try await fixture.addWorktree(onNewBranch: "rebased")
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.runner.run(["rebase", "-q", "main"], in: tree)

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
    let tree = try await fixture.addWorktree(onNewBranch: "merged-in")
    try await fixture.commit("trunk moves on", file: "trunk.txt", content: "a\n")
    _ = try await fixture.runner.run(
      ["merge", "-q", "--no-ff", "-m", "merge the trunk", "main"], in: tree)

    let inputs = try await mergeInputs(fixture)
    let cherry = await WorktreeGit(runner: fixture.runner).isPatchEquivalent(
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
    try await addOrigin(to: fixture)

    try await squashMergeOnTheRemote(
      "squashed", work: [("squashed.txt", "a\n"), ("squashed-too.txt", "b\n")], in: fixture)

    let landed = try await mergeInputs(fixture)
    var states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, inputs: landed)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))

    _ = try await fixture.runner.run(["checkout", "-q", "squashed"], in: path)
    try await fixture.commit("carrying on", file: "squashed.txt", content: "a\nand more\n")
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)

    let after = try await mergeInputs(fixture)
    #expect(after.upstreamIsGone("squashed"), "still gone, and still says nothing about this")
    states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, inputs: after)
    #expect(states["squashed"] == .unmerged, "this worktree holds the only copy of that")
  }

  /// A bare repository logs no branch creation, so nothing is claimed for a branch with no
  /// reflog; see Docs/design/merged-branch.md. Its first commit is still logged.
  @Test func aBareRepositoryClaimsNothingForABranchWithNoReflogButBadgesOneThatLanded() async throws
  {
    let (fixture, checkout) = try await RepositoryFixture.makeBare()
    defer { fixture.tearDown() }
    let bare = fixture.project.path
    let cutFrom = try await fixture.head(of: checkout)
    try await TestRepository.commit(
      "the trunk moves on", files: ["later.txt": "the trunk moves on\n"], in: checkout,
      using: fixture.runner)

    let old = fixture.root.appendingPathComponent("trees/old", isDirectory: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "-b", "old", old.path, cutFrom], in: bare)

    let worktreeGit = WorktreeGit(runner: fixture.runner)
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
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "-b", "work", work.path, "main"], in: bare)
    try await TestRepository.commit(
      "work of its own", files: ["work.txt": "work of its own\n"], in: work, using: fixture.runner)
    _ = try await fixture.runner.run(
      ["merge", "-q", "--no-ff", "-m", "merge work", "work"], in: checkout)

    let landed = try await mergeInputs(fixture)
    states = await fixture.coordinator.mergeStates(
      of: ["work"], in: fixture.project, inputs: landed)
    #expect(states["work"] == .merged(.ancestor, into: "main"))
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
    let inputs = stubInputs(
      baseTip: "MMM", refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await fake.coordinator
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
    let inputs = stubInputs(
      baseTip: "MMM", refs: [BranchRef(fullName: "refs/heads/feat", tip: "FFF")])

    let states = await fake.coordinator
      .mergeStates(of: ["feat"], in: Project(path: fake.directory), inputs: inputs)

    #expect(states.isEmpty, "no answer, rather than an answer of unmerged")
  }

  /// `branch.<name>` config outlives its branch, so a reused name inherits an upstream never
  /// on the remote, which git reports as `[gone]`; see Docs/design/merged-branch.md.
  @Test func aBranchWhoseUpstreamWasNeverThereIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await addOrigin(to: fixture)

    // What the branch that had the name before left behind.
    _ = try await fixture.runner.run(["config", "branch.reused.remote", "origin"], in: path)
    _ = try await fixture.runner.run(
      ["config", "branch.reused.merge", "refs/heads/reused"], in: path)
    let tree = try await fixture.addWorktree(onNewBranch: "reused")

    let cut = try await mergeInputs(fixture)
    #expect(cut.upstreamIsGone("reused"), "git cannot tell the two apart")
    var states = await fixture.coordinator.mergeStates(
      of: ["reused"], in: fixture.project, inputs: cut)
    #expect(states["reused"] == .unmerged, "cut from the trunk and not written in")

    _ = try await fixture.runner.run(["commit", "-q", "--allow-empty", "-m", "work"], in: tree)
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
    try await fixture.commit("second", file: "b.txt", content: "b\n")
    _ = try await fixture.addWorktree(onNewBranch: "fresh")

    let inputs = try await mergeInputs(fixture)
    // git itself calls it merged, which is the whole trap.
    let merged = await WorktreeGit(runner: fixture.runner).mergedBranches(
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
    let tree = try await fixture.addWorktree(onNewBranch: "ff")
    try await TestRepository.commit(
      "work", files: ["a.txt": "a\n"], in: tree, using: fixture.runner)
    _ = try await fixture.runner.run(["merge", "-q", "--ff-only", "ff"], in: path)

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

    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)
    #expect(states["feat"] == .unmerged)
  }

  @Test func aBranchThatLandedAndThenMovedAgainIsUnmergedOnceMore() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)
    _ = try await fixture.runner.run(["checkout", "-q", "feat"], in: path)
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
    try await addOrigin(to: fixture)
    try await fixture.commitOnBranch("develop", "dev", file: "dev.txt", content: "a\n")

    // The clone recorded origin/HEAD, and the remote wins over a local main
    // that a pull has not caught up with.
    let detected = try await mergeInputs(fixture)
    #expect(detected.base.shortName == "origin/main")
    #expect(detected.base.nameWithoutRemote == "main")

    let overridden = try await mergeInputs(fixture, override: "develop")
    #expect(overridden.base.shortName == "develop")
  }

  @Test func aMergeReadOfNoBranchesAnswersNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(of: [], in: fixture.project, inputs: inputs)
    #expect(states.isEmpty)
  }
}
