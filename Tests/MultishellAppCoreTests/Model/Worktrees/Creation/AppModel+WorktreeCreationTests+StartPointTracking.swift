import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelWorktreeCreationTests {
  @Test func aBranchStartedFromAnotherRemoteBranchDoesNotTrackIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feat1 = try await harness.createWorktree(onBranch: "feat1")
    _ = try await harness.git.run(["push", "-q", "-u", "origin", "feat1"], in: feat1.path)

    _ = try #require(
      await harness.model.createWorktree(
        branch: "feat2",
        basedOn: "origin/feat1",
        createsBranch: true,
        in: harness.project,
      )
    )

    let upstream = try? await harness.git.run(
      ["rev-parse", "--abbrev-ref", "feat2@{upstream}"],
      in: harness.project.path,
    )
    #expect(upstream == nil)
  }
}
