import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelServiceReadsTests {
  @Test func aPushedWorktreeShowsThePullRequestItsBranchHeads() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(
      .success([
        .sample(number: 9, headBranch: "feat", headCommit: try await harness.tip(of: feat))
      ])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
    #expect(harness.model.services(of: feat).pullRequestIntegration == .gitHub)
    #expect(host.calls == ["list"], "one call for the whole project")
  }

  @Test func aMergedPullRequestHeadedByTheTipIsProofTheBranchLanded() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let tip = try await harness.tip(of: feat)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: tip)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let state = harness.model.mergeState(of: feat)
    #expect(state == .merged(.pullRequest(number: 9), into: "origin/main"), "named as git's are")
    #expect(state.isCertain, "the removal dialog leads with deleting the branch")
  }

  @Test func aCommitAfterTheMergeLeavesThePullRequestOutgrownAndGitToDecide() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    host.answer(
      .success([
        .sample(
          number: 9,
          state: .merged,
          headBranch: "feat",
          headCommit: try await harness.tip(of: feat),
        )
      ])
    )
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "after"], in: feat.path)

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).pullRequest == nil)
    #expect(harness.model.services(of: feat).outgrownPullRequest?.number == 9)
    #expect(harness.model.mergeState(of: feat) == .unmerged)
  }

  @Test func aBranchBehindItsMergedPullRequestsHeadIsNotOutgrownAndOffersOpen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "update"],
      in: feat.path,
    )
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    _ = try await harness.git.run(["reset", "-q", "--hard", "HEAD~1"], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
    #expect(harness.model.services(of: feat).shownPullRequest?.number == 9)
    #expect(harness.model.pullRequestMenuItem(for: feat) == .open(number: 9))
    #expect(harness.model.mergeState(of: feat) == .unmerged)
  }

  @Test func aBranchAmendedWithNewWorkAfterItsMergeIsOutgrownAndOffersCreate() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let work = feat.path.appendingPathComponent("work.txt")
    try "work\n".write(to: work, atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "work.txt"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    try "work, reworked\n".write(to: work, atomically: true, encoding: .utf8)
    _ = try await harness.git.run(
      ["commit", "-q", "-a", "--amend", "-m", "reworked"],
      in: feat.path,
    )
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest?.number == 9)
    #expect(harness.model.pullRequestMenuItem(for: feat) == .create(isPublishing: false))
  }

  @Test func aBranchTheHostRebasedBeforeMergingIsNotOutgrownAndOffersOpen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try "work\n".write(
      to: feat.path.appendingPathComponent("work.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "work.txt"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let work = try await harness.tip(of: feat)
    let project = harness.project.path
    _ = try await harness.git.run(["checkout", "-q", "-b", "host-rebase", "main"], in: project)
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "base moved"],
      in: project,
    )
    _ = try await harness.git.run(["cherry-pick", work], in: project)
    let rebasedHead = try await harness.git.run(["rev-parse", "HEAD"], in: project)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await harness.git.run(["checkout", "-q", "main"], in: project)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: rebasedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
    #expect(harness.model.pullRequestMenuItem(for: feat) == .open(number: 9))
  }

  @Test func aBranchResetToTheTrunkAfterItsSquashMergeIsNotOutgrown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try "work\n".write(
      to: feat.path.appendingPathComponent("work.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "work.txt"], in: feat.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let project = harness.project.path
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "other (#10)"],
      in: project,
    )
    _ = try await harness.git.run(["checkout", "-q", mergedHead, "--", "work.txt"], in: project)
    _ = try await harness.git.run(["commit", "-q", "-m", "work (#9)"], in: project)
    _ = try await harness.git.run(["update-ref", "refs/remotes/origin/main", "main"], in: project)
    _ = try await harness.git.run(["reset", "-q", "--hard", "origin/main"], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
    #expect(harness.model.services(of: feat).shownPullRequest?.number == 9)
  }

  @Test func aNewCommitPastAMergedPullRequestIsOutgrownThoughTheTrunkIsUnresolved() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    var settings = harness.model.ownSettings(of: harness.project)
    settings.defaultBranch = "no-such-branch"
    harness.model.setSettings(settings, for: harness.project)
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    try await harness.commitFile("after.txt", in: feat)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest?.number == 9)
  }

  @Test func aBranchScanFindsACommitPastAMergedPullRequestThoughTheTrunkIsUnresolved()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    var settings = harness.model.ownSettings(of: harness.project)
    settings.defaultBranch = "no-such-branch"
    harness.model.setSettings(settings, for: harness.project)
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    try await harness.commitFile("after.txt", in: feat)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.services(of: feat).outgrownPullRequest?.number == 9)
  }

  @Test func aCommitLeftOnlyOnTheBranchOnceAnotherRemoteBranchWentIsOutgrownAtTheNextRead()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    try await harness.commitFile("after.txt", in: feat)
    let after = try await harness.tip(of: feat)
    let project = harness.project.path
    _ = try await harness.git.run(["update-ref", "refs/remotes/origin/child", after], in: project)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.services(of: feat).outgrownPullRequest == nil, "origin/child holds it")

    _ = try await harness.git.run(["update-ref", "-d", "refs/remotes/origin/child"], in: project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest?.number == 9)
  }

  @Test func aBranchWithNoCommitsOfItsOwnPastItsHeadIsNeverPatched() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let synced = try await harness.squashOnSideBranch(of: mergedHead)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/main", synced],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["reset", "-q", "--hard", synced], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    harness.git.runLog.setRecording(true)

    await harness.model.refreshServices(ofProject: harness.project.id)

    let runs = harness.git.runLog.drain().finishedRuns
    #expect(runs.contains { $0.command.hasPrefix("rev-list --no-merges") })
    #expect(!runs.contains { $0.command.hasPrefix("cherry") })
  }

  @Test func aBranchThatMergedTheTrunkAfterItsMergeIsNeverPatched() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let synced = try await harness.squashOnSideBranch(of: mergedHead)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/main", synced],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["merge", "-q", "--no-edit", synced], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    harness.git.runLog.setRecording(true)

    await harness.model.refreshServices(ofProject: harness.project.id)

    let runs = harness.git.runLog.drain().finishedRuns
    #expect(runs.contains { $0.command.hasPrefix("rev-list --no-merges") })
    #expect(!runs.contains { $0.command.hasPrefix("cherry") })
    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
  }

  @Test func aBranchThatMergedALocalBranchAheadOfItsRemoteIsNotOutgrown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let main = try #require(harness.worktree(onBranch: "main"))
    try await harness.commitFile("unpushed.txt", in: main)
    _ = try await harness.git.run(["merge", "-q", "--no-edit", "main"], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
  }

  @Test func twoClonesOfOneRepositoryEachGetTheirOwnOutgrownAnswer() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    try await harness.commitFile("after.txt", in: feat)
    let after = try await harness.tip(of: feat)
    let clonePath = harness.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await harness.git.run(
      ["clone", "-q", harness.project.path.path, clonePath.path],
      in: harness.root,
    )
    _ = try await harness.git.run(["checkout", "-q", "feat"], in: clonePath)
    _ = try await harness.git.run(
      ["remote", "set-url", "origin", GitHarness.gitHubOrigin],
      in: clonePath,
    )
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/child", after],
      in: harness.project.path,
    )
    await harness.model.addProject(at: clonePath)
    let clone = try #require(harness.model.workspace.projects.first { $0.path == clonePath })
    let cloneFeat = try #require(harness.model.workspace.worktrees(of: clone.id).first)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    await harness.model.refreshBranchScan(of: clone)
    await harness.model.refreshServices(ofProject: clone.id)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil, "origin/child holds it")
    #expect(harness.model.services(of: cloneFeat).outgrownPullRequest?.number == 9)
  }

  @Test func aBranchResetToAnotherRemotesTrunkAfterItsMergeIsNotOutgrown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let synced = try await harness.squashOnSideBranch(of: mergedHead)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/upstream/main", synced],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["reset", "-q", "--hard", synced], in: feat.path)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: mergedHead)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
  }

  @Test func aStackedBranchThatMergedItsBaseAfterItsMergeIsNotOutgrown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    let base = try await harness.squashOnSideBranch(of: mergedHead)
    _ = try await harness.git.run(
      ["update-ref", "refs/remotes/origin/stack-base", base],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["merge", "-q", "--no-edit", base], in: feat.path)
    host.answer(
      .success([
        .sample(
          number: 9,
          state: .merged,
          headBranch: "feat",
          headCommit: mergedHead,
          baseBranch: "stack-base",
        )
      ])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
  }

  @Test func aMergedHeadThisRepositoryHasNotFetchedLeavesThePullRequestShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let unfetched = String(repeating: "e", count: 40)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: unfetched)])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).outgrownPullRequest == nil)
    #expect(harness.model.services(of: feat).shownPullRequest?.number == 9)
  }

  @Test func anUnfetchedMergedHeadIsAskedAboutOnceNotEveryScan() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let unfetched = String(repeating: "e", count: 40)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: unfetched)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.git.runLog.setRecording(true)

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshBranchScan(of: harness.project)

    let runs = harness.git.runLog.drain().finishedRuns
    #expect(!runs.contains { $0.command.hasPrefix("rev-list --no-merges") })
  }

  @Test func theServicesReadAsksAnUnansweredMergedHeadAgainAsAFetchMayHaveBroughtIt()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    try await harness.pushToGitHubOrigin(feat)
    let unfetched = String(repeating: "e", count: 40)
    host.answer(
      .success([.sample(number: 9, state: .merged, headBranch: "feat", headCommit: unfetched)])
    )
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.git.runLog.setRecording(true)

    await harness.model.refreshServices(ofProject: harness.project.id)

    let runs = harness.git.runLog.drain().finishedRuns
    #expect(runs.contains { $0.command.hasPrefix("rev-list --no-merges") })
  }

  @Test func aFailedReadKeepsWhatTheRowShowedAndSaysWhy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    host.answer(.failure(.failed("HTTP 502: Bad Gateway")))
    await harness.model.refreshServices(ofProject: harness.project.id)

    let services = harness.model.services(of: feat)
    #expect(services.pullRequest?.number == 9)
    #expect(services.readProblem?.failure == .failed("HTTP 502: Bad Gateway"))
    #expect(services.readProblem?.lastAnsweredAt != nil)
  }

  @Test func aRepositoryTheHostDisownsIsNotAskedAgainUntilItsRemotesChange() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))

    await harness.model.refreshServices(ofProject: harness.project.id)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"])

    _ = try await harness.git.run(
      ["remote", "add", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list", "list"])
  }

  @Test func aWorktreeCheckedOutOntoAnotherBranchKeepsNoneOfTheOldOnesServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    _ = try await harness.git.run(["checkout", "-q", "-b", "other"], in: feat.path)
    await harness.model.refreshWorktrees(of: harness.project)

    let other = try #require(harness.worktree(onBranch: "other"))
    #expect(!harness.model.services(of: other).showsAnything)
    #expect(harness.model.remoteState.upstreams[other.id] == nil)
  }

  @Test func turningAnIntegrationOffDropsWhatItReadAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)

    #expect(harness.model.services(of: feat).pullRequest == nil)
    #expect(harness.model.ownSettings(of: harness.project).disabledIntegrations == [.gitHub])
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"], "nothing asked of a host turned off")
  }

  @Test func aReadUnderAnIntegrationTurnedOffDisturbsNoOtherProjectsPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.success([]))
    let other = try await harness.addSecondProject()
    let otherMain = try #require(harness.model.workspace.worktrees(of: other.id).first)
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let model = harness.model
    let fired = AtomicFlag()
    withObservationTracking {
      _ = model.ciPage(of: otherMain)
    } onChange: {
      fired.raise()
    }
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!fired.raised)
  }

  @Test func settingsWrittenWithAnIntegrationOffDropWhatItReadAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    var settings = harness.model.ownSettings(of: harness.project)
    settings.setIntegration(.gitHub, isEnabled: false)
    harness.model.setSettings(settings, for: harness.project)

    #expect(harness.model.services(of: feat).pullRequest == nil)
  }

  @Test func aToolGoneFromThePathDropsWhatItRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.adoptServiceTools(on: harness.root.path)

    #expect(harness.model.services(of: feat).pullRequest == nil)
    #expect(harness.model.remoteState.pullRequests.isEmpty)
  }

  @Test func aProviderTooOldToReadIsNeverAskedAndShowsNoPage() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.refuseReads()

    await harness.model.checkToolsCanRead()
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.isEmpty)
    #expect(!harness.model.showsCIPanelPage)
  }

  @Test func settingsWrittenWithARepeatedIntegrationAreKeptInTheirOneForm() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    var settings = harness.model.ownSettings(of: harness.project)
    settings.disabledIntegrations = [.gitHub, .circleCI, .gitHub]

    harness.model.setSettings(settings, for: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).disabledIntegrations == [.circleCI, .gitHub]
    )
  }

  @Test func aRepositoryWithoutTheProvidersFileIsNeverAskedAboutRuns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()

    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls.isEmpty)
    #expect(
      harness.model.integrationRepositoryFit(.circleCI, for: harness.project) == .notConfigured
    )

    try harness.writeCIConfiguration()
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls == ["recent"])
    #expect(harness.model.integrationRepositoryFit(.circleCI, for: harness.project) == .unknown)
  }

  @Test func aShownBranchTheRecentRunsLeftOutIsAskedAloneUntilItIsPushedTo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    provider.answer(recent: [], byBranch: ["feat": .sample(id: "old", branch: "feat")])
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.services(of: feat).ciRun?.id == "old")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      provider.calls.sorted() == ["branch feat", "branch main", "recent", "recent"],
      "the settled answers stand",
    )
  }

  @Test func oneBranchFailingToAnswerKeepsItsRunAndTakesTheOthersNewOnes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fix = try await harness.createWorktree(onBranch: "fix")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "fix"], in: fix.path)
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(
      recent: [],
      byBranch: [
        "feat": .sample(id: "feat-1", branch: "feat", status: .running),
        "fix": .sample(id: "fix-1", branch: "fix", status: .running),
      ],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "feat-2", branch: "feat")],
    )
    provider.failLookUp(ofBranch: "fix")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "feat-2")
    #expect(harness.model.services(of: fix).ciRun?.id == "fix-1")
  }

  @Test func aBranchFailingToAnswerAloneKeepsTheRunTheRecentRunsGaveIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [.sample(id: "feat-1", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(recent: [])
    provider.failLookUp(ofBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "feat-1")
  }

  @Test func aBranchHiddenForARoundIsNotAskedAloneAgainWhenItReturns() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    provider.answer(recent: [], byBranch: ["feat": .sample(id: "old", branch: "feat")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.sidebarFilterText = "main"
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.services(of: feat).ciRun?.id == "old", "hidden, it keeps its run")
    harness.model.sidebarFilterText = ""
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls.filter { $0 == "branch feat" } == ["branch feat"])
  }

  @Test func aLookupMadeBeforeTheRunExistedIsNotBroughtBackOnceTheRecentRunsDropIt()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [])
    await harness.model.refreshServices(ofProject: harness.project.id)
    let first = CIRun.sample(id: "r1", branch: "feat")
    provider.answer(recent: [first], byBranch: ["feat": first])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.answer(recent: [], byBranch: ["feat": first])
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "r1")
  }

  @Test func aFailedLookupKeepsTheRunTheRowShowedOverAnOlderLookup() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(
      recent: [],
      byBranch: ["feat": .sample(id: "r1", branch: "feat", status: .running)],
    )
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.ciRuns[harness.project.id]?.lookups["feat"] =
      BranchRunLookup(upstreamTip: "older", run: nil)

    provider.failLookUp(ofBranch: "feat")
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun?.id == "r1")
  }

  @Test func aBranchFailingToAnswerAloneIsTheOnlyRowSaidToBeOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    let fix = try await harness.createWorktree(onBranch: "fix")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "fix"], in: fix.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [], byBranch: ["feat": .sample(id: "f", branch: "feat")])
    provider.failLookUp(ofBranch: "fix")

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).readProblem == nil)
    #expect(harness.model.services(of: fix).readProblem?.lastAnsweredAt == nil)
    #expect(harness.model.services(of: fix).readProblem?.failure == .failed("offline"))
  }

  @Test func aProviderThatDisownsTheRepositoryTakesItsRunsOffTheRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [.sample(id: "r1", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.failRecent(.notHosted)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil)
  }

  @Test func aReadLandingAfterItsProjectWasRemovedLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.removeProject(harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func aReadSettlingAfterTheAppLeftTheFrontAsksNothingAndIsLeftDue() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    let id = harness.project.id
    harness.model.scheduleServicesRead(of: id)
    let pending = try #require(harness.model.remoteState.pendingReads[id])

    harness.platform.isActive = false
    await pending.value

    #expect(host.calls.isEmpty)
    #expect(harness.model.remoteState.readLog.isDue(id, at: .now))
  }

  @Test func anUpstreamMovingInTheBackgroundSchedulesNoRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    harness.platform.isActive = false

    harness.model.scheduleServicesRead(of: harness.project.id)

    #expect(harness.model.remoteState.pendingReads[harness.project.id] == nil)
  }

  @Test func aReadLandingAfterItsIntegrationWasTurnedOffLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func aRunsOnlyReadQueuedBehindAReadListsNoPullRequestsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    await harness.model.refreshServices(ofProject: id, readsPullRequests: false)
    host.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list"])
    #expect(provider.calls.filter { $0 == "recent" }.count == 2)
  }

  @Test func aListLandingAfterItsToolLeftThePathLeavesNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { host.calls == ["list"] }

    harness.model.remoteState.connections = .empty
    host.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.pullRequestsAnsweredAt[id] == nil)
  }

  @Test func runsLandingAfterTheirToolLeftThePathLeaveNoAnswerTime() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    provider.holdRecent()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.model.remoteState.connections = .empty
    provider.releaseHeldReads()
    await read.value

    #expect(harness.model.remoteState.ciRunsAnsweredAt[id] == nil)
  }

  @Test func aProviderFoundTooOldTakesWhatItReadOffTheRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(harness.model.remoteState.ciRuns[harness.project.id] != nil)

    provider.refuseReads()
    await harness.model.checkToolsCanRead()

    #expect(harness.model.remoteState.ciRuns[harness.project.id] == nil)
  }

  @Test func aBranchWhoseRemoteBranchIsGoneIsNotAskedAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(!provider.calls.contains("branch feat"))
  }

  @Test func anUpstreamMovingInTheBackgroundIsReadOnTheReturnHoweverRecentTheLastRead()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.platform.isActive = false

    harness.model.scheduleServicesRead(of: harness.project.id)

    #expect(
      harness.model.remoteState.readLog.isDue(
        harness.project.id,
        at: .now,
        interval: ServiceReadInterval.activation,
      )
    )
  }

  @Test func aReadSpanningAnIntegrationTurnedOffAndOnAgainIsNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    host.holdList()
    host.answer(.failure(.failed("offline")))
    let read = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls.count == 2 }

    harness.model.setIntegration(.gitHub, isEnabled: false, for: harness.project)
    harness.model.setIntegration(.gitHub, isEnabled: true, for: harness.project)
    host.releaseHeldReads()
    await read.value

    #expect(
      harness.model.services(of: feat).pullRequest == nil,
      "the list read before it went is not this one's",
    )
  }

  @Test func turningOneIntegrationOffMidReadReadsTheOtherAgainAtOnce() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    await harness.model.refreshBranchScan(of: harness.project)
    provider.holdRecent()
    let read = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func anIntegrationTurnedOffMidReadInTheBackgroundLeavesTheReadDueNotRun() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    defer { provider.releaseHeldReads() }
    provider.holdRecent()
    let id = harness.project.id
    let read = Task { _ = await harness.model.refreshServices(ofProject: id) }
    try await waitUntil { provider.calls.contains("recent") }

    harness.platform.isActive = false
    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.releaseHeldReads()
    await read.value
    try await waitUntil { harness.servicesAreSettled() }

    #expect(host.calls == ["list"], "nothing is asked in the background")
    #expect(harness.model.remoteState.readLog.isDue(id, at: .now))
  }

  @Test func onlyACheckedOutBranchIsAskedWhereItWasMadeFrom() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    _ = try await harness.git.run(
      ["push", "-q", "origin", "HEAD:refs/heads/release"],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["fetch", "-q", "origin"], in: harness.project.path)
    _ = try await harness.git.run(
      ["branch", "-q", "--track", "side", "origin/release"],
      in: harness.project.path,
    )
    harness.git.runLog.setRecording(true)

    await harness.model.refreshBranchScan(of: harness.project)

    let asked = harness.git.runLog.drain().finishedRuns.filter { $0.command.hasPrefix("reflog") }
    #expect(asked.isEmpty, "side has no worktree, so no row to show")
  }

  @Test func aBranchMadeOutsideTheWorktreeFolderKeepsTheTeammatesBranchItFollows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let project = harness.project.path
    _ = try await harness.git.run(
      ["push", "-q", "origin", "HEAD:refs/heads/alice/fix"],
      in: project,
    )
    _ = try await harness.git.run(["fetch", "-q", "origin"], in: project)
    _ = try await harness.git.run(
      ["switch", "-q", "-c", "review", "origin/alice/fix"],
      in: project,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let review = try #require(harness.worktree(onBranch: "review"))

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[review.id]?.branch == "alice/fix")
  }

  @Test func anOlderScanLandingLastLeavesTheNewerOnesUpstreams() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let project = harness.project.path
    _ = try await harness.git.run(
      ["push", "-q", "origin", "HEAD:refs/heads/release"],
      in: project,
    )
    _ = try await harness.git.run(["fetch", "-q", "origin"], in: project)
    _ = try await harness.git.run(
      ["branch", "-q", "--track", "side", "origin/release"],
      in: project,
    )
    let sidePath = harness.model.effectiveWorktreeSettings(for: harness.project)
      .worktreePath(forBranch: "side", in: harness.project)
    _ = try await harness.git.run(["worktree", "add", "-q", sidePath.path, "side"], in: project)
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshWorktrees(of: harness.project)
    let slow = harness.root.appendingPathComponent("reflog-slow")
    let started = harness.root.appendingPathComponent("reflog-started")
    let gate = harness.root.appendingPathComponent("reflog-gate")
    try Data().write(to: slow)
    let wrapper = try Scratch.script(
      """
      case "$*" in *reflog*) [ -e '\(slow.path)' ] && /usr/bin/touch '\(started.path)' && \(harness.holdLine(until: gate)) ;; esac
      exec git "$@"
      """,
      at: harness.root.appendingPathComponent("fake-git"),
    )
    harness.model.coordinator = TestGit.coordinator(
      runner: try GitRunner(executable: wrapper, configuration: ["commit.gpgsign": "false"])
    )
    harness.model.remoteState.branchStartPoints = [:]
    let older = Task { await harness.model.refreshBranchScan(of: harness.project) }
    try await waitUntil { FileManager.default.fileExists(atPath: started.path) }
    #expect(
      FileManager.default.fileExists(atPath: started.path),
      "the older scan reads the reflog",
    )

    try FileManager.default.removeItem(at: slow)
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "more"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    try Data().write(to: gate)
    await older.value

    #expect(harness.model.remoteState.upstreams[feat.id]?.tip == (try await harness.tip(of: feat)))
  }

  @Test func aBranchWhoseStartPointGitFailedToReadIsAskedAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    let project = harness.project.path
    _ = try await harness.git.run(
      ["push", "-q", "origin", "HEAD:refs/heads/release"],
      in: project,
    )
    _ = try await harness.git.run(["fetch", "-q", "origin"], in: project)
    _ = try await harness.git.run(
      ["branch", "-q", "--track", "side", "origin/release"],
      in: project,
    )
    let sidePath = harness.model.effectiveWorktreeSettings(for: harness.project)
      .worktreePath(forBranch: "side", in: harness.project)
    _ = try await harness.git.run(["worktree", "add", "-q", sidePath.path, "side"], in: project)
    let failing = harness.root.appendingPathComponent("reflog-fails")
    try Data().write(to: failing)
    let wrapper = try Scratch.script(
      "case \"$*\" in *reflog*) [ -e '\(failing.path)' ] && exit 1 ;; esac\nexec git \"$@\"",
      at: harness.root.appendingPathComponent("fake-git"),
    )
    harness.model.coordinator = TestGit.coordinator(
      runner: try GitRunner(executable: wrapper, configuration: ["commit.gpgsign": "false"])
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    await harness.model.refreshBranchScan(of: harness.project)
    #expect(harness.model.remoteState.upstreams[side.id] != nil)

    try FileManager.default.removeItem(at: failing)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[side.id] == nil)
  }

  @Test func aProviderFoundAbleToReadReadsItsRunsAndNotThePullRequestsAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.refuseReads()
    await harness.model.checkToolsCanRead()
    await harness.model.refreshServices(ofProject: harness.project.id)

    provider.allowReads()
    await harness.model.checkToolsCanRead()
    try await waitUntil { provider.calls.contains("recent") }
    await harness.model.remoteState.servicePoll?.value

    #expect(host.calls == ["list"])
  }

  @Test func aProviderFoundAbleToReadBeforeAnyListAnsweredReadsThePullRequestsToo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.refuseReads()
    await harness.model.checkToolsCanRead()

    provider.allowReads()
    await harness.model.checkToolsCanRead()
    try await waitUntil { provider.calls.contains("recent") && harness.servicesAreSettled() }

    #expect(host.calls == ["list"])
  }

  @Test func aProviderFoundAbleToReadInTheBackgroundLeavesItsProjectsDue() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.refuseReads()
    await harness.model.checkToolsCanRead()
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.platform.isActive = false

    provider.allowReads()
    await harness.model.checkToolsCanRead()

    #expect(harness.model.remoteState.readLog.isDue(harness.project.id, at: .now))
  }

  @Test func aBranchsKeptLookupIsNotRedatedByARoundThatDidNotAskIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [], byBranch: ["feat": .sample(id: "old", branch: "feat")])
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?["feat"] = .distantPast

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?["feat"] == .distantPast
    )
  }

  @Test func noPollStartsWhileTheAppIsInTheBackground() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    harness.platform.isActive = false

    harness.model.startServicePoll()

    #expect(harness.model.remoteState.servicePoll == nil)
  }

  @Test func anIntegrationTurnedOffAndOnAgainSaysItsFailedReadWasNeverAnswered() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.setIntegration(.circleCI, isEnabled: false, for: harness.project)
    provider.failRecent(.loggedOut)
    harness.model.setIntegration(.circleCI, isEnabled: true, for: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let problem = try #require(harness.model.services(of: feat).readProblem)
    #expect(problem.lastAnsweredAt == nil)
  }

  @Test func branchAnswerTimesAreKeptOnlyForBranchesAWorktreeFollows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    provider.answer(recent: [
      .sample(id: "a", branch: "feat"), .sample(id: "b", branch: "someone-else"),
    ])

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.remoteState.ciBranchesAnsweredAt[harness.project.id]?.keys.sorted()
        == ["feat", "main"],
      "main's checkout follows origin/main",
    )
  }

  @Test func aProjectIsNotCountedAskedBeforeAToolIsThereToAsk() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.pollServices()
    let (host, _) = harness.connectServices()
    await harness.model.pollServices()

    #expect(host.calls == ["list"], "due at once, not an interval after launch")
  }

  @Test func aReadAskedForDuringAnotherFollowsIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let first = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }

    await harness.model.refreshServices(ofProject: harness.project.id)
    host.releaseHeldReads()
    await first.value

    try await waitUntil({ host.calls.count == 2 }, seconds: 3)
    #expect(host.calls == ["list", "list"], "what moved during the first is read after it")
  }

  @Test func aReadAskedForDuringAnotherWaitsForTheFrontWhereTheAppWentBehind() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdList()
    let first = Task { _ = await harness.model.refreshServices(ofProject: harness.project.id) }
    try await waitUntil { host.calls == ["list"] }
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.platform.isActive = false
    host.releaseHeldReads()
    await first.value

    #expect(harness.model.remoteState.readLog.isDue(harness.project.id, at: .now))
    try await waitUntil { harness.servicesAreSettled() }
    #expect(host.calls == ["list"])
  }

  @Test func aHungReadHoldsUpNoPollRound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.pushToGitHubOrigin(feat)
    host.answer(.success([.sample(number: 9, headBranch: "feat")]))
    host.holdList()
    let finished = Recorder<Bool>()

    Task {
      await harness.model.pollRound()
      finished.record(true)
    }
    try await waitUntil({ !finished.received.isEmpty }, seconds: 3)

    #expect(finished.received == [true])
    host.releaseHeldReads()
    try await waitUntil { harness.model.services(of: feat).pullRequest != nil }
    #expect(harness.model.services(of: feat).pullRequest?.number == 9)
  }

  @Test func aReadWithNoToolToAskDoesNotCountTheProjectAsked() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.refreshServices(ofProject: harness.project.id)
    let (host, _) = harness.connectServices()
    await harness.model.pollServices()

    #expect(host.calls == ["list"], "due at once, not an interval after the empty read")
  }

  @Test func aReturnToTheFrontDuringAPollReadsWhatItMakesDueOnceThePollEnds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.addSecondProject()
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    let aMinuteAgo = ContinuousClock.now - .seconds(60)
    _ = harness.model.remoteState.readLog.begin(other.id, at: aMinuteAgo)
    harness.model.remoteState.readLog.finish(other.id)
    host.holdList()
    harness.model.startServicePoll()
    try await waitUntil { host.calls == ["list"] }

    harness.model.startServicePoll(interval: ServiceReadInterval.activation)
    host.releaseHeldReads()

    try await waitUntil({ host.calls.count == 2 }, seconds: 3)
    #expect(host.calls == ["list", "list"], "the other project, past the return's 30 s")
  }

  @Test func aPushMovingTheUpstreamReadsTheServicesAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(host.calls == ["list"])

    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    try await waitUntil({ host.calls.count == 2 }, seconds: 5)
    #expect(host.calls == ["list", "list"])
  }

  @Test func aBranchCutFromTheTrunkThatStillTracksItTakesNoneOfTheTrunksServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    _ = try await harness.git.run(
      ["branch", "-q", "--set-upstream-to=origin/main", "main"],
      in: harness.project.path,
    )
    let directory = harness.root.appendingPathComponent("feat", isDirectory: true)
    _ = try await harness.git.run(
      ["worktree", "add", "-q", "--track", "-b", "feat", directory.path, "origin/main"],
      in: harness.project.path,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let feat = try #require(harness.worktree(onBranch: "feat"))
    provider.answer(recent: [.sample(id: "trunk", branch: "main")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil, "main's run is not feat's")
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )
    let main = try #require(harness.worktree(onBranch: "main"))
    #expect(harness.model.services(of: main).ciRun?.id == "trunk", "the trunk's own row keeps it")
  }

  @Test func aBranchTrackingALocalBranchIsNotPushed() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    try await harness.addOrigin()
    _ = try await harness.git.run(["branch", "-q", "stack"], in: harness.project.path)
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["branch", "-q", "--set-upstream-to=stack"], in: feat.path)
    provider.answer(recent: [.sample(id: "stack-run", branch: "stack")])
    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.services(of: feat).ciRun == nil, "stack's run is not feat's")
    #expect(
      harness.model.pullRequestPage(of: feat)
        == .noPullRequest(branch: "feat", isPushed: false)
    )
  }

  @Test func aBranchStartedFromAnotherRemoteBranchTakesNoneOfItsServices() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.connectServices()
    try await harness.addOrigin()
    _ = try await harness.git.run(
      ["push", "-q", "origin", "HEAD:refs/heads/release"],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["fetch", "-q", "origin"], in: harness.project.path)
    let directory = harness.model.effectiveWorktreeSettings(for: harness.project)
      .worktreePath(forBranch: "feature", in: harness.project)
    _ = try await harness.git.run(
      ["worktree", "add", "-q", "-b", "feature", directory.path, "origin/release"],
      in: harness.project.path,
    )
    await harness.model.refreshWorktrees(of: harness.project)
    let feature = try #require(harness.worktree(onBranch: "feature"))

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(
      harness.model.remoteState.upstreams[feature.id] == nil,
      "release's pull request is not feature's",
    )
  }

  @Test func gitsOwnProofStandsOverAMergedPullRequest() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    _ = try await harness.git.run(["commit", "-q", "--allow-empty", "-m", "work"], in: feat.path)
    _ = try await harness.git.run(
      ["merge", "-q", "--no-ff", "-m", "merge", "feat"],
      in: harness.project.path,
    )
    _ = try await harness.git.run(["push", "-q", "origin", "main"], in: harness.project.path)
    try await harness.pushToGitHubOrigin(feat)
    host.answer(
      .success([
        .sample(
          number: 9,
          state: .merged,
          headBranch: "feat",
          headCommit: try await harness.tip(of: feat),
        )
      ])
    )

    await harness.model.refreshBranchScans()
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(harness.model.mergeState(of: feat) == .merged(.ancestor, into: "origin/main"))
  }

  @Test func aMergedPullRequestNeverCallsTheTrunkMerged() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let main = try #require(harness.worktree(onBranch: "main"))
    _ = try await harness.git.run(
      ["push", "-q", "-u", "origin", "main"],
      in: harness.project.path,
    )
    _ = try await harness.git.run(
      ["remote", "set-url", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    host.answer(
      .success([
        .sample(
          number: 3,
          state: .merged,
          headBranch: "main",
          headCommit: try await harness.tip(of: main),
        )
      ])
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(
      harness.model.services(of: main).pullRequest?.number == 3,
      "its row may show the pull request",
    )
    #expect(harness.model.mergeState(of: main) == .unknown, "but the trunk is never merged")
  }

  @Test func aRepositoryTheHostDisownedIsAskedAgainOnceTheAnswerIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))
    await harness.model.refreshServices(ofProject: harness.project.id)

    harness.model.remoteState.pullRequests[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.calls == ["list", "list"], "a login since may have made it the host's")
  }

  @Test func aDisownedRepositoryAskedAgainWaitsAnotherIntervalAfterTheSameAnswer() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    host.answer(.failure(.notHosted))
    await harness.model.refreshServices(ofProject: harness.project.id)
    harness.model.remoteState.pullRequests[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(host.calls == ["list", "list"])
  }

  @Test func aRepositoryTheProviderDisownsIsNotAskedAgainUntilTheAnswerIsOld() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (_, provider) = harness.connectServices()
    try harness.writeCIConfiguration()
    provider.failRecent(.notHosted)
    await harness.model.refreshServices(ofProject: harness.project.id)

    await harness.model.refreshServices(ofProject: harness.project.id)

    #expect(provider.calls == ["recent"])
    harness.model.remoteState.ciRuns[harness.project.id]?.notHostedSince = .distantPast
    await harness.model.refreshServices(ofProject: harness.project.id)
    #expect(provider.calls == ["recent", "recent"])
  }
}
