import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelChangesPastHeadTests {
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
    try await harness.commitFile("work.txt", in: feat)
    try await harness.pushToGitHubOrigin(feat)
    let mergedHead = try await harness.tip(of: feat)
    try "work, reworked\n".write(
      to: feat.path.appendingPathComponent("work.txt"),
      atomically: true,
      encoding: .utf8,
    )
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
    try await harness.commitFile("work.txt", in: feat)
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
    try await harness.commitFile("work.txt", in: feat)
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
}
