import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

extension AppModelWorktreeRemovalRequestTests {
  /// A squash merge leaves the commits off the trunk and the host deletes the
  /// remote branch, so `git branch -d` refuses; the host's word deletes it.
  private func squashMergedFeat(
    _ harness: GitHarness,
    baseBranch: String = "main",
  ) async throws -> Worktree {
    let (host, _) = harness.connectServices()
    try await harness.addOrigin()
    let feat = try await harness.createWorktree(onBranch: "feat")
    try await harness.commitFile("work.txt", in: feat)
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat"], in: feat.path)
    _ = try await harness.git.run(["push", "-q", "origin", "--delete", "feat"], in: feat.path)
    _ = try await harness.git.run(["fetch", "-q", "--prune", "origin"], in: feat.path)
    _ = try await harness.git.run(
      ["remote", "set-url", "origin", GitHarness.gitHubOrigin],
      in: harness.project.path,
    )
    host.answer(
      .success([
        .sample(
          number: 9,
          state: .merged,
          headBranch: "feat",
          headCommit: try await harness.tip(of: feat),
          baseBranch: baseBranch,
        )
      ])
    )
    await harness.model.refreshBranchScans()
    await harness.model.refreshServices(ofProject: harness.project.id)
    await harness.model.refreshStatuses()
    return feat
  }

  @Test func removingASquashMergedPullRequestsWorktreeDeletesItsBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)

    await harness.model.requestWorktreeRemoval(of: feat)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)
    #expect(pending.choices.first?.deletesBranch == true, "proof leads with deleting the branch")
    await harness.model.answerWorktreeRemoval(pending, choice: 0)?.value
    try await harness.awaitOperationEnd(on: feat.id)

    #expect(harness.model.presentedError == nil)
    #expect(try await harness.branches() == ["main"])
  }

  @Test func aCommitMadeWhileTheDialogIsUpKeepsTheBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)
    await harness.model.requestWorktreeRemoval(of: feat)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)

    try await harness.commitFile("late.txt", in: feat)
    await harness.model.answerWorktreeRemoval(pending, choice: 0)?.value
    try await harness.awaitOperationEnd(on: feat.id)

    #expect(try await harness.branches().contains("feat"))
  }

  @Test func settingsThatDeleteWithoutAskingDeleteASquashMergedBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)
    harness.model.setConfirmsWorktreeRemoval(false)
    harness.model.setDeletesBranchWithWorktree(true)

    await harness.model.requestWorktreeRemoval(of: feat)?.value
    try await harness.awaitOperationEnd(on: feat.id)

    #expect(harness.model.presentedError == nil)
    #expect(try await harness.branches() == ["main"])
  }

  @Test func aPullRequestMergedIntoAnotherBranchIsNoProofItLanded() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness, baseBranch: "stack")

    #expect(harness.model.mergeState(of: feat).isCertain == false)
  }
}
