import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

/// The merged badge and the fetch behind it: what each worktree is
/// measured against, and what a pass that finds nothing moved costs.
extension AppModelGitTests {
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
    #expect(h.model.mergeBase(of: h.project)?.ref == "main", "no remote, so the local branch")

    _ = try await h.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: h.project.path)
    await h.model.refreshMergeStates()

    #expect(h.model.mergeState(of: feat) == .merged(.ancestor, into: "main"))
    #expect(h.model.mergeState(of: main) == .unknown, "the trunk is not merged into itself")
    #expect(h.model.presentedError == nil)
  }

  /// The check runs on the status poll, so a pass that finds nothing moved
  /// must not touch the observable state: writing a dictionary entry back
  /// unchanged still tells every view watching it to draw again, and this
  /// would do that to the whole sidebar every five seconds.
  @Test func aPassThatChangesNothingDoesNotDisturbTheViews() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "feat", basedOn: nil, createBranch: true, in: h.project)
    await h.model.refreshMergeStates()

    let model = h.model
    let fired = Fired()
    withObservationTracking {
      _ = model.mergeStates
      _ = model.mergeBases
    } onChange: {
      fired.value = true
    }
    await h.model.refreshMergeStates()

    #expect(!fired.value, "nothing moved, so nothing to redraw")
  }

  /// A git call that failed is not an answer, and must not be recorded as
  /// one: the verdict it could not replace would then be pinned to the new
  /// tip and never asked about again.
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

  /// The ref read answers two questions at once, so a failure taken as an
  /// answer would say the project has no branches: every badge dropped, the
  /// base forgotten and every commit date the rows are ordered by blanked,
  /// on one bad read.
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
    #expect(model.mergeBase(of: h.project)?.ref == "main")

    await model.refreshMergeStates()

    #expect(model.mergeBase(of: h.project)?.ref == "main", "a failed read settles nothing")
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
  @Test func asecondPassAsksGitNothingAboutABranchThatHasNotMoved() async throws {
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

  /// The verdict is memoised on what it was drawn from, and whether the
  /// upstream was gone is part of that. A first push puts one back under a
  /// branch that had none, moving neither the branch nor the trunk, and the
  /// badge the missing upstream earned has to go with it.
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
    // Real changes, and two of them: the commit the forge squashes them into
    // shares a patch id with neither, so only the gone upstream is left to
    // answer for the branch.
    try await commit("work", file: "feat.txt", content: "a\n", in: feat.path, with: h.git)
    try await commit("more work", file: "feat-too.txt", content: "b\n", in: feat.path, with: h.git)
    _ = try await h.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    // The forge squashes the branch onto main and deletes it.
    // One commit carrying the branch's whole tree, as a squash does. Two
    // mirroring its own would be a cherry-pick, which `git cherry` answers
    // for before the upstream is ever read.
    try await commit(
      "squashed work", files: ["feat.txt": "a\n", "feat-too.txt": "b\n"], in: path, with: h.git)
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

  private func commit(
    _ message: String, file: String, content: String, in directory: URL, with git: GitRunner
  ) async throws {
    try await commit(message, files: [file: content], in: directory, with: git)
  }

  private func commit(
    _ message: String, files: [String: String], in directory: URL, with git: GitRunner
  ) async throws {
    for (file, content) in files {
      try content.write(
        to: directory.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }
    _ = try await git.run(["add", "."], in: directory)
    _ = try await git.run(["commit", "-q", "-m", message], in: directory)
  }
}
