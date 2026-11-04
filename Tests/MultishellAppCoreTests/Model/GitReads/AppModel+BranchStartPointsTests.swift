import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite(.serialized) @MainActor
struct AppModelBranchStartPointsTests {
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
    try harness.wrapGit(in: "case \"$*\" in *reflog*) [ -e '\(failing.path)' ] && exit 1 ;; esac")
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    await harness.model.refreshBranchScan(of: harness.project)
    #expect(harness.model.remoteState.upstreams[side.id] != nil)

    try FileManager.default.removeItem(at: failing)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.remoteState.upstreams[side.id] == nil)
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
}
