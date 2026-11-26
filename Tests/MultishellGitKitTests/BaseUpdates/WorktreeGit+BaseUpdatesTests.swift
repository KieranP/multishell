import Foundation
import MultishellCore
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitBaseUpdatesTests {
  /// `origin/main` one unfetched commit past a `feature` worktree with one of its own;
  /// each writes README.md as given, so differing texts conflict.
  private static func featureBehindOrigin(
    readme: String = "hello\n",
    featureReadme: String? = nil,
  ) async throws -> (fixture: RepositoryFixture, feature: Worktree, landed: String) {
    let fixture = try await RepositoryFixture.make()
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    var files = ["feature.txt": "feature\n"]
    if let featureReadme { files["README.md"] = featureReadme }
    try await TestRepository.commit("feature work", files: files, in: path, using: fixture.runner)
    let fetched = try await fixture.head(of: fixture.project.path)
    try await fixture.commit("landed", files: ["landed.txt": "landed\n", "README.md": readme])
    _ = try await fixture.runner.run(["push", "-q", "origin", "main"], in: fixture.project.path)
    _ = try await fixture.runner.run(
      ["update-ref", "refs/remotes/origin/main", fetched],
      in: fixture.project.path,
    )
    let landed = try await fixture.head(of: fixture.project.path)
    return (fixture, try await fixture.worktree(onBranch: "feature"), landed)
  }

  /// A `feature` worktree and `main` each writing README.md differently, in a
  /// repository whose refs git keeps in reftable, with no pseudo-ref files.
  private static func reftableFeatureConflictingWithMain() async throws -> (
    fixture: RepositoryFixture, feature: Worktree
  ) {
    let fixture = try await RepositoryFixture.make()
    _ = try await fixture.runner.run(
      ["refs", "migrate", "--ref-format=reftable"],
      in: fixture.project.path,
    )
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await TestRepository.commit(
      "feature work",
      files: ["README.md": "from feature\n"],
      in: path,
      using: fixture.runner,
    )
    try await fixture.commit("main work", file: "README.md", content: "from main\n")
    return (fixture, try await fixture.worktree(onBranch: "feature"))
  }

  private static func contains(
    _ commit: String,
    _ worktree: Worktree,
    _ fixture: RepositoryFixture,
  ) async -> Bool {
    await fixture.runner.succeeds(
      ["merge-base", "--is-ancestor", commit, "HEAD"],
      in: worktree.path,
    )
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func anUpdateFetchesTheBaseFirstAndTakesInWhatLanded(method: UpdateMethod) async throws {
    let (fixture, feature, landed) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    let base = try await fixture.defaultBranch()

    let outcome = try await fixture.git.fetchThenUpdate(feature, from: base, by: method)

    #expect(outcome == .updated)
    #expect(await Self.contains(landed, feature, fixture))
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == nil)
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func aConflictStopsTheUpdateAndLeavesItInProgress(method: UpdateMethod) async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    let base = try await fixture.defaultBranch()

    let outcome = try await fixture.git.fetchThenUpdate(feature, from: base, by: method)
    let status = try await fixture.git.status(of: feature)

    #expect(outcome == .unfinished(conflictedPaths: ["README.md"]))
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == method)
    #expect(status.unfinishedUpdate == method)
    #expect(status.conflicted == 1)
    #expect(!status.isCleanAndInSync)
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func anAbortPutsTheBranchBackWhereItWas(method: UpdateMethod) async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    let before = try await fixture.head(of: feature.path)
    _ = try await fixture.git.fetchThenUpdate(
      feature,
      from: try await fixture.defaultBranch(),
      by: method,
    )

    try await fixture.git.abortUpdate(feature, method: method)

    #expect(try await fixture.head(of: feature.path) == before)
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == nil)
    #expect(try await fixture.git.status(of: feature).unfinishedUpdate == nil)
  }

  @Test func aStoppedMergeInTheMainCheckoutIsReadFromItsOwnGitDirectory() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commitOnBranch("side", file: "README.md", content: "from side\n")
    try await fixture.commit("main work", file: "README.md", content: "from main\n")
    _ = try? await fixture.runner.run(["merge", "--no-edit", "side"], in: fixture.project.path)

    #expect(await fixture.git.unfinishedUpdate(in: fixture.project.path) == .merge)
  }

  @Test func aRebaseBegunAgainFromANewTipIsMarkedAsAnotherStop() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    #expect(await fixture.git.unfinishedUpdateMark(in: feature.path) == nil)
    _ = try? await fixture.runner.run(["rebase", "main"], in: feature.path)
    let first = await fixture.git.unfinishedUpdateMark(in: feature.path)
    _ = try await fixture.runner.run(["rebase", "--abort"], in: feature.path)
    try await TestRepository.commit(
      "more",
      files: ["more.txt": "more\n"],
      in: feature.path,
      using: fixture.runner,
    )
    _ = try? await fixture.runner.run(["rebase", "main"], in: feature.path)

    #expect(first != nil)
    #expect(await fixture.git.unfinishedUpdateMark(in: feature.path) != first)
  }

  @Test func aRebaseStoppedOnAMergeStepKeepsTheMarkOfItsPickStops() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    _ = try? await fixture.runner.run(["rebase", "main"], in: feature.path)
    let pickStop = await fixture.git.unfinishedUpdateMark(in: feature.path)
    let gitDirectory = try await fixture.runner.run(
      ["rev-parse", "--absolute-git-dir"],
      in: feature.path,
    ).trimmingCharacters(in: .whitespacesAndNewlines)
    let mergeStepHead = try await fixture.head(of: fixture.project.path)
    try "\(mergeStepHead)\n".write(
      toFile: gitDirectory + "/MERGE_HEAD",
      atomically: true,
      encoding: .utf8,
    )

    #expect(await fixture.git.unfinishedUpdateMark(in: feature.path) == pickStop)
  }

  @Test func aRebaseFailingOverAMergeSomeoneElseStoppedIsGitsFailureNotItsConflicts()
    async throws
  {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    let racing = try TestGit.runner(
      wrappingRealGitIn: #"[ "$1" = rebase ] && git merge --no-edit main >/dev/null 2>&1"#,
      at: fixture.root.appendingPathComponent("racing-git"),
    )
    let git = TestGit.coordinator(runner: racing).git

    await #expect(throws: ProcessFailure.self) {
      _ = try await git.update(feature, from: try await fixture.defaultBranch(), by: .rebase)
    }
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == .merge)
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func anUpdateFailingOverAStopOfItsKindSomeoneElseBeganIsGitsFailure(
    method: UpdateMethod
  ) async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    let racing = try TestGit.runner(
      wrappingRealGitIn:
        #"[ "$1" = \#(method.rawValue) ] && git \#(method.rawValue) main >/dev/null 2>&1"#,
      at: fixture.root.appendingPathComponent("racing-git"),
    )
    let git = TestGit.coordinator(runner: racing).git

    await #expect(throws: ProcessFailure.self) {
      _ = try await git.update(feature, from: try await fixture.defaultBranch(), by: method)
    }
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == method)
  }

  @Test func aMergeOfTheSameTipSomeoneElseBeganFromAnotherCommitIsGitsFailure() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["fetch", "-q", "origin"], in: feature.path)
    let racing = try TestGit.runner(
      wrappingRealGitIn: #"""
        [ "$1" = merge ] && git commit -q --allow-empty -m agent \
          && git merge origin/main >/dev/null 2>&1
        """#,
      at: fixture.root.appendingPathComponent("racing-git"),
    )
    let git = TestGit.coordinator(runner: racing).git

    await #expect(throws: ProcessFailure.self) {
      _ = try await git.update(feature, from: try await fixture.defaultBranch(), by: .merge)
    }
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == .merge)
  }

  @Test(.enabled(if: TestGit.migratesRefs))
  func aMergeStoppedInAReftableRepositoryIsItsOwnStop() async throws {
    let (fixture, feature) = try await Self.reftableFeatureConflictingWithMain()
    defer { fixture.tearDown() }

    let outcome = try await fixture.git.fetchThenUpdate(
      feature,
      from: try await fixture.defaultBranch(),
      by: .merge,
    )

    #expect(outcome == .unfinished(conflictedPaths: ["README.md"]))
  }

  @Test(.enabled(if: TestGit.migratesRefs))
  func aCherryPickStoppedInAReftableRepositoryPicksCommits() async throws {
    let (fixture, feature) = try await Self.reftableFeatureConflictingWithMain()
    defer { fixture.tearDown() }
    _ = try? await fixture.runner.run(["cherry-pick", "main"], in: feature.path)

    #expect(await fixture.git.isPickingCommits(in: feature.path))
  }

  @Test(.enabled(if: TestGit.migratesRefs))
  func aTagNamedLikeAPseudoRefInAReftableRepositoryIsNoStoppedPick() async throws {
    let (fixture, feature) = try await Self.reftableFeatureConflictingWithMain()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["tag", "REVERT_HEAD"], in: feature.path)

    #expect(!(await fixture.git.isPickingCommits(in: feature.path)))
  }

  @Test func aStoppedGitAmIsNoRebaseButPicksCommits() async throws {
    let (fixture, feature, landed) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    let patch = fixture.root.appendingPathComponent("landed.patch")
    let text = try await fixture.runner.run(
      ["format-patch", "-1", "--stdout", landed],
      in: fixture.project.path,
    )
    try text.write(to: patch, atomically: true, encoding: .utf8)
    _ = try? await fixture.runner.run(["am", patch.path], in: feature.path)

    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == nil)
    #expect(await fixture.git.isPickingCommits(in: feature.path))
  }

  @Test func aRebaseStartedDetachedNamesNoBranchBeingRebased() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "--detach"], in: feature.path)
    _ = try? await fixture.runner.run(["rebase", "main"], in: feature.path)

    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == .rebase)
    #expect(await fixture.git.branchBeingRebased(in: feature.path) == nil)
  }

  @Test func aCherryPickSequenceWithItsStopCommittedStillPicksCommits() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(
      readme: "from main\n",
      featureReadme: "from feature\n",
    )
    defer { fixture.tearDown() }
    try await fixture.commit("after", file: "after.txt", content: "after\n")
    _ = try? await fixture.runner.run(["cherry-pick", "main~1", "main"], in: feature.path)
    try "settled\n".write(
      to: feature.path.appendingPathComponent("README.md"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await fixture.runner.run(["add", "README.md"], in: feature.path)
    _ = try await fixture.runner.run(["commit", "-q", "--no-edit"], in: feature.path)

    #expect(await fixture.git.isPickingCommits(in: feature.path))
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func anUpdateFindingTheIndexLockedFailsAsLockedAndStartsNothing(
    method: UpdateMethod
  ) async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    let before = try await fixture.head(of: feature.path)
    let gitDirectory = try #require(WorktreeGit.recordDirectoryFromGitFile(in: feature.path))
    try Data().write(to: gitDirectory.appendingPathComponent("index.lock"))

    await #expect(throws: IndexLocked.self) {
      _ = try await fixture.git.fetchThenUpdate(
        feature,
        from: try await fixture.defaultBranch(),
        by: method,
      )
    }
    #expect(try await fixture.head(of: feature.path) == before)
    #expect(await fixture.git.unfinishedUpdate(in: feature.path) == nil)
  }

  @Test(arguments: [UpdateMethod.merge, .rebase])
  func anUpdateNeverAutostashesWhateverTheConfigSays(method: UpdateMethod) async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin(readme: "from main\n")
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["config", "rebase.autoStash", "true"], in: feature.path)
    _ = try await fixture.runner.run(["config", "merge.autoStash", "true"], in: feature.path)
    try "dirty\n".write(
      to: feature.path.appendingPathComponent("README.md"),
      atomically: true,
      encoding: .utf8,
    )

    await #expect(throws: ProcessFailure.self) {
      _ = try await fixture.git.fetchThenUpdate(
        feature,
        from: try await fixture.defaultBranch(),
        by: method,
      )
    }
    let stashes = try await fixture.runner.run(["stash", "list"], in: feature.path)
    #expect(stashes.isEmpty)
  }

  @Test func aRebaseLeavesBranchesStackedOnItWhateverTheConfigSays() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["config", "rebase.updateRefs", "true"], in: feature.path)
    _ = try await fixture.runner.run(["branch", "feature-part"], in: feature.path)
    let stacked = try await fixture.head(of: feature.path)

    _ = try await fixture.git.fetchThenUpdate(
      feature,
      from: try await fixture.defaultBranch(),
      by: .rebase,
    )

    let part = try await fixture.runner.run(["rev-parse", "feature-part"], in: feature.path)
    #expect(part.trimmingCharacters(in: .whitespacesAndNewlines) == stacked)
  }

  @Test func aMergeConfiguredFastForwardOnlyStillMakesItsMergeCommit() async throws {
    let (fixture, feature, landed) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["config", "merge.ff", "only"], in: feature.path)

    let outcome = try await fixture.git.fetchThenUpdate(
      feature,
      from: try await fixture.defaultBranch(),
      by: .merge,
    )

    #expect(outcome == .updated)
    #expect(await Self.contains(landed, feature, fixture))
  }

  @Test func aMergeCommitNamesTheBaseByItsShortName() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }

    _ = try await fixture.git.fetchThenUpdate(
      feature,
      from: try await fixture.defaultBranch(),
      by: .merge,
    )

    let subject = try await fixture.runner.run(["log", "-1", "--format=%s"], in: feature.path)
    #expect(subject == "Merge remote-tracking branch 'origin/main' into feature\n")
  }

  @Test func uncommittedChangesAreListedAsStatusLetters() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try fixture.write("changed\n", to: "README.md")
    try fixture.write("new\n", to: "notes.md")
    let main = try await fixture.worktree(onBranch: "main")

    let changes = try await fixture.git.uncommittedChanges(in: main)

    #expect(changes == ["M README.md", "? notes.md"])
  }

  @Test func aBranchIsPushedWhereAnyRemoteHoldsItsName() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let tracked = try await fixture.addWorktree(onNewBranch: "tracked")
    let untracked = try await fixture.addWorktree(onNewBranch: "untracked")
    _ = try await fixture.addWorktree(onNewBranch: "local")
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "tracked"], in: tracked)
    _ = try await fixture.runner.run(
      ["push", "-q", "origin", "untracked:untracked"],
      in: untracked,
    )

    #expect(
      await fixture.git.isPushed(try await fixture.worktree(onBranch: "tracked"))
    )
    #expect(
      await fixture.git.isPushed(
        try await fixture.worktree(onBranch: "untracked")
      )
    )
    #expect(
      !(await fixture.git.isPushed(try await fixture.worktree(onBranch: "local")))
    )
  }

  @Test func aBranchPushedOnlyToAForkWhileTrackingTheBaseIsPushed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.addFork()
    let path = try await fixture.addWorktree(onNewBranch: "feature", from: "origin/main")
    _ = try await fixture.runner.run(["push", "-q", "fork", "feature:feature"], in: path)
    let feature = try await fixture.worktree(onBranch: "feature")

    #expect(await fixture.git.isPushed(feature))
  }

  @Test func aBranchTrackingAnotherRemoteBranchItWasCutFromIsNotPushed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    _ = try await fixture.runner.run(
      ["push", "-q", "origin", "main:release-2"],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["fetch", "-q", "origin"], in: fixture.project.path)
    _ = try await fixture.addWorktree(onNewBranch: "feature", from: "origin/release-2")
    let feature = try await fixture.worktree(onBranch: "feature")

    #expect(!(await fixture.git.isPushed(feature)))
  }

  @Test func aBranchTrackingTheBaseItWasCutFromIsNotPushed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    _ = try await fixture.addWorktree(onNewBranch: "feature", from: "origin/main")
    let feature = try await fixture.worktree(onBranch: "feature")
    let upstream = try await fixture.runner.run(
      ["rev-parse", "--abbrev-ref", "@{upstream}"],
      in: feature.path,
    )

    #expect(upstream == "origin/main\n")
    #expect(!(await fixture.git.isPushed(feature)))
  }

  @Test func aMergeAHookRejectsFailsWithGitsWordsAndIsNoStop() async throws {
    let (fixture, feature, _) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    let hook = fixture.project.path.appendingPathComponent(".git/hooks/commit-msg")
    try "#!/bin/sh\necho 'no ticket in the message' >&2\nexit 1\n".write(
      to: hook,
      atomically: true,
      encoding: .utf8,
    )
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)

    await #expect {
      _ = try await fixture.git.fetchThenUpdate(
        feature,
        from: try await fixture.defaultBranch(),
        by: .merge,
      )
    } throws: { error in
      (error as? ProcessFailure)?.message.contains("no ticket in the message") == true
    }
  }

  @Test func aBaseOnARemoteWithASlashInItsNameIsFetchedFromThatRemote() async throws {
    let (fixture, feature, landed) = try await Self.featureBehindOrigin()
    defer { fixture.tearDown() }
    let origin = fixture.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await fixture.runner.run(
      ["remote", "add", "team/origin", origin.path],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["fetch", "-q", "team/origin"], in: fixture.project.path)
    let refs = await fixture.git.branchRefs(fixture.project) ?? []
    let base = try #require(DefaultBranch.resolve(from: refs, override: "team/origin/main"))

    let outcome = try await fixture.git.fetchThenUpdate(feature, from: base, by: .merge)

    #expect(outcome == .updated)
    #expect(await Self.contains(landed, feature, fixture))
  }

  @Test func aBranchPushedToARemoteWithASlashInItsNameIsPushed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let origin = fixture.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await fixture.runner.run(
      ["remote", "add", "team/origin", origin.path],
      in: fixture.project.path,
    )
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    _ = try await fixture.runner.run(["push", "-q", "team/origin", "feature:feature"], in: path)
    let feature = try await fixture.worktree(onBranch: "feature")

    #expect(await fixture.git.isPushed(feature))
  }

  @Test func aBranchOnlyNamedLikeAnotherOnARemoteIsNotPushed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "fix")
    _ = try await fixture.runner.run(["push", "-q", "origin", "fix:fix/deeper"], in: path)
    let fix = try await fixture.worktree(onBranch: "fix")

    #expect(!(await fixture.git.isPushed(fix)))
  }

  @Test func aPushedReadThatFailsCountsAsPushedSoTheRebaseAsks() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    _ = try await fixture.addWorktree(onNewBranch: "feature")
    let feature = try await fixture.worktree(onBranch: "feature")
    let failing = try TestGit.runner(
      wrappingRealGitIn: #"[ "$1" = for-each-ref ] && exit 1"#,
      at: fixture.root.appendingPathComponent("failing-git"),
    )

    #expect(await TestGit.coordinator(runner: failing).git.isPushed(feature))
  }

  @Test func aRemoteTrackingBaseWhoseRemoteIsGoneFailsRatherThanUpdatingStale() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.addWorktree(onNewBranch: "feature")
    _ = try await fixture.runner.run(
      ["update-ref", "refs/remotes/old/main", "main"],
      in: fixture.project.path,
    )
    let refs = await fixture.git.branchRefs(fixture.project) ?? []
    let base = try #require(DefaultBranch.resolve(from: refs, override: "old/main"))
    let feature = try await fixture.worktree(onBranch: "feature")

    await #expect(throws: BaseRemoteMissing.self) {
      try await fixture.git.fetch(base, into: feature)
    }
  }

  @Test func aLocalBaseIsUpdatedFromWithoutAFetch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await TestRepository.commit(
      "work",
      files: ["a.txt": "a\n"],
      in: path,
      using: fixture.runner,
    )
    try await fixture.commit("landed", file: "b.txt", content: "b\n")
    let landed = try await fixture.head(of: fixture.project.path)
    let feature = try await fixture.worktree(onBranch: "feature")
    let base = try await fixture.defaultBranch()

    let outcome = try await fixture.git.fetchThenUpdate(feature, from: base, by: .rebase)

    #expect(!base.isRemoteTracking)
    #expect(outcome == .updated)
    #expect(await Self.contains(landed, feature, fixture))
  }
}
