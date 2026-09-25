import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

/// The merged badge and the fetch behind it: what each worktree is
/// measured against, and what a pass that finds nothing moved costs.
@Suite(.serialized) @MainActor
struct AppModelMergesTests {
  @Test func aBranchThatLandsGetsItsBadgeAndTheMainWorktreeNeverDoes() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))
    let main = try #require(h.worktree(onBranch: "main"))

    // Cut from the trunk's own tip and not yet written in: an ancestor of
    // main from the moment it existed, and not merged.
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unmerged, "a worktree just made is not merged")

    _ = try await h.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unmerged)
    #expect(
      h.model.defaultBranch(of: h.project)?.shortName == "main", "no remote, so the local branch")

    _ = try await h.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: h.project.path)
    await h.model.refreshMergeStates()

    #expect(h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"))
    #expect(h.model.mergeState(of: main) == .unknown, "the trunk is not merged into itself")
    #expect(h.model.presentedError == nil)
  }

  @Test func aLoneProjectsRefreshLeavesTheRoundsBudgetAsItFoundIt() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    h.model.mergeReads.budget = .seconds(2)
    h.model.mergeReads.remember(["a": .seconds(1), "b": .seconds(1), "c": .seconds(1)])
    h.model.mergeReads.remember(["d": .seconds(1)])
    h.model.mergeReads.beginRound()
    #expect(h.model.mergeReads.admit(["a", "b"], sharingRound: true).count == 2)

    await h.model.refreshMergeStates(of: h.project)

    #expect(h.model.mergeReads.admit(["c", "d"], sharingRound: true).count == 1)
  }

  @Test func aTrunkThatMovedUnderEveryBranchIsReAskedOverSeveralRounds() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    for branch in ["one", "two", "three"] {
      await h.model.createWorktree(branch: branch, basedOn: nil, createBranch: true, in: h.project)
    }
    let trees = try ["one", "two", "three"].map { try #require(h.worktree(onBranch: $0)) }
    for tree in trees {
      _ = try await h.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: tree.path)
    }
    await h.model.refreshMergeStates()
    #expect(trees.allSatisfy { h.model.mergeState(of: $0) == .unmerged })
    h.model.mergeReads.budget = .zero

    for tree in trees {
      _ = try await h.git.run(
        ["merge", "-q", "--no-ff", "-m", "merge", tree.name], in: h.project.path)
    }
    let merged = { trees.filter { h.model.mergeState(of: $0) != .unmerged }.count }
    await h.model.refreshMergeStates()
    #expect(merged() == 1, "one read a round where the budget allows none")
    await h.model.refreshMergeStates()
    #expect(merged() == 2)
    await h.model.refreshMergeStates()
    #expect(merged() == 3, "and none left behind")
  }

  /// The badge reads "safe to remove", so a claimed path or a running stage hides it; a
  /// removal's own badge stands while its hook runs.
  @Test func aWorktreeStillBeingBuiltDoesNotWearTheMergedBadge() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))
    _ = try await h.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    _ = try await h.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: h.project.path)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"))

    h.model.pathClaims.claim(feat.id)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unknown, "a claimed path forgets")

    h.model.pathClaims.release(feat.id)
    h.model.worktreeOperations.begin(.postCreateHook, on: feat.id)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .unknown, "and a stage computes nothing new")

    h.model.worktreeOperations.finish(.postCreateHook, on: feat.id)
    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"), "and back after")

    h.model.worktreeOperations.begin(.preDeleteHook, on: feat.id)
    await h.model.refreshMergeStates()
    #expect(
      h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"),
      "a removal keeps the badge it is asking about")
  }

  /// Writing a dictionary entry back unchanged still redraws every view watching it, and the
  /// status poll would do that to the whole sidebar every five seconds.
  @Test func aPassThatChangesNothingDoesNotDisturbTheViews() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    await h.model.refreshMergeStates()

    let model = h.model
    let fired = Flag()
    withObservationTracking {
      _ = model.mergeStates
      _ = model.defaultBranches
    } onChange: {
      fired.raise()
    }
    await h.model.refreshMergeStates()

    #expect(!fired.raised, "nothing moved, so nothing to redraw")
  }

  /// A verdict recorded from a failed call would be pinned to the new tip and never asked
  /// about again.
  @Test func aFailedReadLeavesTheBranchToBeAskedAboutAgain() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))

    // Tip AAA, then BBB, and `branch --merged` fails on every pass after
    // the first: the branch moved, and nothing can say where it stands.
    let model = try h.modelOnFakeGit(
      """
      SEEN="$SCRATCH/passes"
      printf x >> "$SEEN"
      PASS=$(wc -c < "$SEEN" | tr -d ' ')
      case "$*" in
        for-each-ref*)
          if [ "$PASS" -le 2 ]; then TIP=AAA; else TIP=BBB; fi
          printf 'refs/heads/main\\tMMM\\t\\t\\nrefs/heads/feat\\t%s\\t\\t\\n' "$TIP" ;;
        branch\\ --merged*)
          if [ "$PASS" -le 2 ]; then echo main; else exit 128; fi ;;
        cherry*) echo '+ AAA' ;;
        *) exit 0 ;;
      esac
      """)

    await model.refreshMergeStates()
    #expect(model.mergeState(of: feat) == .unmerged, "a first answer, from a working git")

    await model.refreshMergeStates()
    let afterFailure = h.gitCalls().filter { $0.hasPrefix("branch --merged") }.count

    await model.refreshMergeStates()
    let afterRetry = h.gitCalls().filter { $0.hasPrefix("branch --merged") }.count
    #expect(afterRetry > afterFailure, "the failed pass must not settle the question")
  }

  @Test func aBranchWhoseReadKeepsFailingWaitsItsTurnBehindOneNeverRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    for branch in ["bad", "good"] {
      await h.model.createWorktree(branch: branch, basedOn: nil, createBranch: true, in: h.project)
    }
    let good = try #require(h.worktree(onBranch: "good"))
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*)
          printf 'refs/heads/main\\tMMM\\t\\t\\nrefs/heads/bad\\tBBB\\t\\t\\nrefs/heads/good\\tGGG\\t\\t\\n' ;;
        branch\\ --merged*) echo main ;;
        cherry*bad*) exit 128 ;;
        cherry*) echo '+ AAA' ;;
        *) exit 0 ;;
      esac
      """)
    model.mergeReads.budget = .zero

    await model.refreshMergeStates()
    await model.refreshMergeStates()

    #expect(model.mergeState(of: good) == .unmerged)
  }

  /// The ref read answers two questions, so a failure taken as an answer drops every badge,
  /// the base, and every commit date the rows are ordered by.
  @Test func aFailedRefReadLeavesTheBaseAndTheBadgesWhereTheyWere() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*)
          if [ -f "$SCRATCH/read-once" ]; then exit 128; fi
          : > "$SCRATCH/read-once"
          printf 'refs/heads/main\\tMMM\\t\\t\\n' ;;
        branch\\ --merged*) echo main ;;
        *) exit 0 ;;
      esac
      """)

    await model.refreshMergeStates()
    #expect(model.defaultBranch(of: h.project)?.shortName == "main")

    await model.refreshMergeStates()

    #expect(
      model.defaultBranch(of: h.project)?.shortName == "main", "a failed read settles nothing")
  }

  /// A fetch waits on a network, so the sidebar has to say it is happening
  /// and a second click must not start another one.
  @Test func aFetchMarksItsProjectForAllOfItAndRefusesASecond() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        fetch*) sleep 1 ;;
        worktree\\ list*)
          printf 'worktree %s\\nHEAD abc\\nbranch refs/heads/main\\n\\n' "$SCRATCH/demo" ;;
        for-each-ref*) printf 'refs/heads/main\\tAAA\\t\\t\\n' ;;
        *) exit 0 ;;
      esac
      """)
    let project = h.project
    #expect(!model.isFetching(project))

    let running = Task { await model.fetch(project) }
    for _ in 0..<200 where !model.isFetching(project) { await Task.yield() }
    #expect(model.isFetching(project), "marked before it waits on anything")

    // The menu item is disabled by this, but a keyboard repeat or a second
    // window must not get past it either.
    await model.fetch(project)
    #expect(model.isFetching(project), "the first one is still running")

    await running.value
    #expect(!model.isFetching(project))
    #expect(
      h.gitCalls().filter { $0.hasPrefix("fetch") }.count == 1, "one fetch, not two")
    // The mark covers the re-reads too: they are what the user clicked for.
    #expect(h.gitCalls().contains { $0.hasPrefix("for-each-ref") })
  }

  /// The badge is on the status poll, so what it costs when nothing has
  /// moved is the ceiling on how often it may run.
  @Test func projectsAreScannedForBranchesSeveralAtATime() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let other = h.root.appendingPathComponent("other", isDirectory: true)
    try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
    h.store.addProject(at: other)
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*)
          touch "$SCRATCH/scan-$$"; sleep 0.5
          ls "$SCRATCH" | grep -c '^scan-' >> "$SCRATCH/overlap"; rm -f "$SCRATCH/scan-$$" ;;
      esac
      """)

    await model.refreshMergeStates()

    let overlap = try String(
      contentsOf: h.root.appendingPathComponent("overlap"), encoding: .utf8)
    #expect(
      overlap.split(separator: "\n").contains {
        Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 >= 2
      },
      "\(overlap)")
  }

  @Test func aSlowProjectHoldsOnlyItsOwnSlotWhileTheOthersAreScanned() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    try "".write(
      to: h.project.path.appendingPathComponent(".slow"), atomically: true, encoding: .utf8)
    for name in ["p1", "p2", "p3", "p4"] {
      let other = h.root.appendingPathComponent(name, isDirectory: true)
      try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
      h.store.addProject(at: other)
    }
    let release = h.root.appendingPathComponent("release")
    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*)
          if [ -e .slow ]; then
            i=0
            while [ ! -e "$SCRATCH/release" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i+1)); done
          else
            echo "$PWD" >> "$SCRATCH/scanned"
          fi ;;
      esac
      """)
    let scanned = {
      ((try? String(
        contentsOf: h.root.appendingPathComponent("scanned"), encoding: .utf8)) ?? "")
        .split(separator: "\n").count
    }

    let round = Task { await model.refreshMergeStates() }
    try await waitUntil { scanned() == 4 }
    let scannedWhileHeld = scanned()
    try "".write(to: release, atomically: true, encoding: .utf8)
    await round.value

    #expect(scannedWhileHeld == 4)
  }

  @Test func aSecondPassAsksGitNothingAboutABranchThatHasNotMoved() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)

    let model = try h.modelOnFakeGit(
      """
      case "$*" in
        for-each-ref*) printf 'refs/heads/main\\tAAA\\t\\t\\nrefs/heads/feat\\tBBB\\t\\t\\n' ;;
        branch\\ --merged*) echo main ;;
        cherry*) echo '+ BBB' ;;
      esac
      """)

    await model.refreshMergeStates()
    let first = h.gitCalls()
    #expect(first.filter { $0.hasPrefix("branch --merged") }.count == 1)
    #expect(first.contains { $0.hasPrefix("cherry") })
    let feat = try #require(h.worktree(onBranch: "feat"))
    #expect(model.mergeState(of: feat) == .unmerged)

    await model.refreshMergeStates()
    let second = h.gitCalls().dropFirst(first.count)

    #expect(!second.contains { $0.hasPrefix("branch --merged") || $0.hasPrefix("cherry") })
    #expect(second.count == 1, "the one read that says nothing moved, and nothing else")
    #expect(model.mergeState(of: feat) == .unmerged)
  }

  /// The verdict is memoised on its inputs, the gone upstream included: a first push puts one
  /// back without moving either tip.
  @Test func aBadgeFromAGoneUpstreamGoesWhenAPushPutsTheUpstreamBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let path = h.project.path
    let origin = h.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await h.git.run(["clone", "-q", "--bare", path.path, origin.path], in: h.root)
    _ = try await h.git.run(["remote", "add", "origin", origin.path], in: path)
    _ = try await h.git.run(["fetch", "-q", "origin"], in: path)

    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    let feat = try #require(h.worktree(onBranch: "feat"))
    // Two real commits: the squash shares a patch id with neither, so only the gone
    // upstream answers for the branch.
    try await TestRepository.commit("work", files: ["feat.txt": "a\n"], in: feat.path, using: h.git)
    try await TestRepository.commit(
      "more work", files: ["feat-too.txt": "b\n"], in: feat.path, using: h.git)
    _ = try await h.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    // The forge squashes onto main as one commit of the branch's whole tree; two mirroring
    // its own would be a cherry-pick, which `git cherry` answers for first.
    try await TestRepository.commit(
      "squashed work", files: ["feat.txt": "a\n", "feat-too.txt": "b\n"], in: path, using: h.git)
    _ = try await h.git.run(["push", "-q", "origin", "main"], in: path)
    _ = try await h.git.run(["push", "-q", "origin", "--delete", "feat"], in: path)
    _ = try await h.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    await h.model.refreshMergeStates()
    #expect(h.model.mergeState(of: feat) == .merged(.upstreamGone, into: "origin/main"))

    // Pushed again: the upstream is back, and neither tip has moved.
    _ = try await h.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await h.model.refreshMergeStates()

    #expect(h.model.mergeState(of: feat) == .unmerged, "the sign it was badged on is gone")
    #expect(h.model.presentedError == nil)
  }

  @Test func theDefaultBranchFieldShowsTheDetectedBranchWithoutItsRemote() {
    let h = Harness()
    #expect(h.model.defaultBranchName(of: h.project) == "main", "nothing detected yet")

    h.model.defaultBranches[h.project.id] = DefaultBranch(
      shortName: "origin/trunk", branchName: "trunk", tip: "abc",
      fullName: "refs/remotes/origin/trunk")

    #expect(h.model.defaultBranchName(of: h.project) == "trunk")
  }
}
