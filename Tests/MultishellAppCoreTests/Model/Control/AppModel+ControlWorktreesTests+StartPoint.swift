import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelControlWorktreesTests {
  private func onOtherWork(_ harness: GitHarness) async throws {
    _ = try await harness.git.run(
      ["checkout", "-q", "-b", "upgrade-deps"],
      in: harness.project.path,
    )
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "deps"],
      in: harness.project.path,
    )
  }

  private func tip(of ref: String, in harness: GitHarness) async throws -> String {
    try await harness.git.run(["rev-parse", ref], in: harness.project.path)
  }

  private func head(of branch: String, in harness: GitHarness) async throws -> String {
    let created = try #require(harness.worktree(onBranch: branch))
    return try await harness.git.run(["rev-parse", "HEAD"], in: created.path)
  }

  @Test func withoutFromTheBranchStartsAtTheDefaultBranchNotTheCheckoutsOwn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await onOtherWork(harness)

    _ = await harness.model.answer(.newWorktree(order("fix", in: harness)))

    #expect(try await head(of: "fix", in: harness) == tip(of: "main", in: harness))
  }

  @Test func fromStillNamesWhereTheBranchStarts() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await onOtherWork(harness)
    let order = NewWorktreeOrder(
      branch: "fix",
      projectID: ControlID.project(harness.project.id),
      createsBranch: true,
      startPoint: "upgrade-deps",
      agentID: nil,
      task: nil,
    )

    _ = await harness.model.answer(.newWorktree(order))

    #expect(try await head(of: "fix", in: harness) == tip(of: "upgrade-deps", in: harness))
  }

  @Test func existingChecksOutThatBranchRatherThanTheDefaultOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await onOtherWork(harness)
    _ = try await harness.git.run(["checkout", "-q", "main"], in: harness.project.path)
    let order = NewWorktreeOrder(
      branch: "upgrade-deps",
      projectID: ControlID.project(harness.project.id),
      createsBranch: false,
      startPoint: nil,
      agentID: nil,
      task: nil,
    )

    _ = await harness.model.answer(.newWorktree(order))

    #expect(
      try await head(of: "upgrade-deps", in: harness) == tip(of: "upgrade-deps", in: harness)
    )
  }
}
