import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelPublishedUpstreamsTests {
  @Test func aNewBranchReusingTheNameOfAnOldRemoteBranchHasNoUpstreamBeforeItIsPushed() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await worktreeReusingAnOldRemoteBranchName(in: harness)

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(
      harness.model.remoteState.upstreams[feat.id] == nil,
      "origin/feat is the old branch's, so its pull request is not this one's",
    )
  }

  @Test func aReusedNameIsPublishedOnceTheNewBranchIsPushedThere() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    _ = try await harness.git.run(["push", "-q", "-f", "origin", "feat:feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    let tip = try await harness.git.run(["rev-parse", "feat"], in: feat.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(
      harness.model.remoteState.upstreams[feat.id]
        == BranchUpstream(remote: "origin", branch: "feat", tip: tip)
    )
  }

  @Test func aSecondScanAtTheSameTipsReadsNoReflog() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    await harness.model.refreshBranchScan(of: harness.project)
    harness.git.runLog.setRecording(true)

    await harness.model.refreshBranchScan(of: harness.project)

    let asked = harness.git.runLog.drain().finishedRuns.filter { $0.command.hasPrefix("reflog") }
    #expect(asked.isEmpty)
  }

  @Test func aReusedNameTakesTheRemoteBranchOnceResetOntoIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    _ = try await harness.git.run(["reset", "-q", "--hard", "origin/feat"], in: feat.path)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[feat.id]?.branch == "feat")
  }

  @Test func aReusedNameWithNoReflogKeepsTheRemoteBranchOfItsName() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    try FileManager.default.removeItem(
      at: harness.project.path.appendingPathComponent(".git/logs/refs/heads/feat")
    )

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[feat.id]?.branch == "feat")
  }

  @Test func aForkBranchOfTheSameNameNeverPushedFromHereFallsBackOnTheTrackedOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let repository = harness.project.path
    let fork = harness.root.appendingPathComponent("fork.git")
    _ = try await harness.git.run(
      ["clone", "-q", "--bare", repository.path, fork.path],
      in: harness.root,
    )
    _ = try await harness.git.run(["remote", "add", "fork", fork.path], in: repository)
    let old = try await harness.createWorktree(onBranch: "old-work")
    try await harness.commitFile("old.txt", in: old)
    _ = try await harness.git.run(["push", "-q", "fork", "old-work:feat"], in: old.path)
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("new.txt", in: feat)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat:feat"], in: feat.path)
    _ = try await harness.git.run(["config", "branch.feat.pushRemote", "fork"], in: repository)

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(
      harness.model.remoteState.upstreams[feat.id]
        == BranchUpstream(remote: "origin", branch: "feat", tip: try await harness.tip(of: feat))
    )
  }

  @Test func aBranchNoWorktreeHasOutIsNotCheckedAndItsCheckIsDropped() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    await harness.model.refreshBranchScan(of: harness.project)
    let id = harness.project.id
    #expect(harness.model.remoteState.publishedTipChecks[id]?["feat"] != nil)

    await harness.model.removeWorktree(feat, deletesBranch: false)
    harness.git.runLog.setRecording(true)
    await harness.model.refreshBranchScan(of: harness.project)

    let asked = harness.git.runLog.drain().finishedRuns.filter { $0.command.hasPrefix("reflog") }
    #expect(asked.isEmpty)
    #expect(harness.model.remoteState.publishedTipChecks[id]?["feat"] == nil)
  }

  @Test func aRemovedProjectsChecksGoWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await worktreeReusingAnOldRemoteBranchName(in: harness)
    await harness.model.refreshBranchScan(of: harness.project)
    let id = harness.project.id

    harness.model.removeProject(harness.project)

    #expect(harness.model.remoteState.publishedTipChecks[id] == nil)
  }

  @Test func aNewWorktreeReusingAMergedBranchsNameShowsNoPullRequestBeforeItIsPushed() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let old = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("old.txt", in: old)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat:feat"], in: old.path)
    let oldTip = try await harness.tip(of: old)
    await harness.model.removeWorktree(
      old,
      deletesBranch: true,
      forcesBranchDeletion: true,
      trashes: false,
    )
    let feat = try #require(
      await harness.model.createWorktree(
        branch: "feat",
        basedOn: "origin/main",
        createsBranch: true,
        in: harness.project,
      )
    )
    try await harness.commitFile("new.txt", in: feat)
    _ = try await harness.git.run(
      ["remote", "set-url", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    host.answer(.success([.sample(number: 8, state: .closed, headCommit: oldTip)]))
    host.answer(
      branch: "feat",
      .success([.sample(number: 9, state: .merged, headCommit: oldTip)]),
    )

    await harness.model.refreshBranchScan(of: harness.project)
    await harness.model.refreshServices(ofProject: harness.project.id)

    let services = harness.model.services(of: feat)
    #expect(services.pullRequest == nil)
    #expect(services.outgrownPullRequest == nil)
    #expect(host.askedBranches.isEmpty)
    #expect(
      harness.model.mergeState(of: feat) != .merged(.pullRequest(number: 9), into: "origin/main")
    )
  }

  @Test func aBranchPushedUnderItsOwnNameWithoutTrackingItIsPublishedThere() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feat = try #require(
      await harness.model.createWorktree(
        branch: "feat",
        basedOn: "origin/main",
        createsBranch: true,
        in: harness.project,
      )
    )
    try await harness.commitFile("pushed.txt", in: feat)
    _ = try await harness.git.run(["push", "-q", "origin", "feat:feat"], in: feat.path)
    try await harness.commitFile("unpushed.txt", in: feat)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[feat.id]?.branch == "feat")
    #expect(harness.model.remoteState.upstreams[feat.id]?.tip != nil)
  }

  private func worktreeReusingAnOldRemoteBranchName(in harness: GitHarness) async throws -> Worktree
  {
    try await harness.addOrigin()
    let old = try await harness.createWorktree(onBranch: "old-work")
    try await harness.commitFile("old.txt", in: old)
    _ = try await harness.git.run(["push", "-q", "origin", "old-work:feat"], in: old.path)
    let feat = try #require(
      await harness.model.createWorktree(
        branch: "feat",
        basedOn: "origin/main",
        createsBranch: true,
        in: harness.project,
      )
    )
    try await harness.commitFile("new.txt", in: feat)
    return feat
  }
}
