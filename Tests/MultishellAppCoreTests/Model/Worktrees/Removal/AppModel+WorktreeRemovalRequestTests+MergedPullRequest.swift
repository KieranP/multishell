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
    try await commitWork(named: "work", in: feat, harness)
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

  private func commitWork(
    named name: String,
    in worktree: Worktree,
    _ harness: GitHarness,
  )
    async throws
  {
    try "\(name)\n".write(
      to: worktree.path.appendingPathComponent("\(name).txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "."], in: worktree.path)
    _ = try await harness.git.run(["commit", "-q", "-m", name], in: worktree.path)
  }

  @Test func removingASquashMergedPullRequestsWorktreeDeletesItsBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)

    await harness.model.requestWorktreeRemoval(of: feat)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)
    #expect(pending.choices.first?.deletesBranch == true, "proof leads with deleting the branch")
    await harness.model.answerWorktreeRemoval(pending, choice: 0)?.value
    await harness.awaitOperationEnd(on: feat.id)

    #expect(harness.model.presentedError == nil)
    #expect(try await harness.branches() == ["main"])
  }

  @Test func aCommitMadeWhileTheDialogIsUpKeepsTheBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)
    await harness.model.requestWorktreeRemoval(of: feat)?.value
    let pending = try #require(harness.model.pendingWorktreeRemoval)

    try await commitWork(named: "late", in: feat, harness)
    await harness.model.answerWorktreeRemoval(pending, choice: 0)?.value
    await harness.awaitOperationEnd(on: feat.id)

    #expect(try await harness.branches().contains("feat"))
  }

  @Test func settingsThatDeleteWithoutAskingDeleteASquashMergedBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feat = try await squashMergedFeat(harness)
    harness.model.setConfirmsWorktreeRemoval(false)
    harness.model.setDeletesBranchWithWorktree(true)

    await harness.model.requestWorktreeRemoval(of: feat)?.value
    await harness.awaitOperationEnd(on: feat.id)

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
