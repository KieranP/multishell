import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelWorktreeCreationTests {
  private func createFromTheSheet(typing text: String, _ harness: GitHarness) async throws {
    var draft = NewWorktreeDraft(projectID: harness.project.id)
    draft.typeBranch(text)
    draft.finishLoading(
      harness.project.id,
      with: NewWorktreeBranches(
        hasCommits: true,
        localBranches: ["main"],
        remoteBranches: [],
        currentBranch: "main",
      ),
      checkedOut: ["main"],
    )
    #expect(draft.canCreate(checkedOut: ["main"]), "\(text.debugDescription)")
    await harness.model.createWorktree(
      branch: draft.branch,
      basedOn: draft.startPoint,
      createsBranch: draft.createsBranch,
      in: harness.project,
    )
  }

  @Test func aPastedControllerActionCreatesTheDashedBranchAndFolder() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    try await createFromTheSheet(typing: "Admin::UsersController#index", harness)

    #expect(harness.model.presentedError == nil)
    let created = try #require(harness.worktree(onBranch: "Admin-UsersController-index"))
    #expect(created.path.lastPathComponent == "Admin-UsersController-index")
    #expect(try await harness.branches().contains("Admin-UsersController-index"))
  }

  @Test func aNameLeftWithTrailingSpacesCreatesTheBranchWithoutThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    try await createFromTheSheet(typing: "feature/foo \t", harness)

    #expect(harness.model.presentedError == nil)
    let created = try #require(harness.worktree(onBranch: "feature/foo"))
    #expect(created.path.lastPathComponent == "feature-foo")
    #expect(try await harness.branches().contains("feature/foo"))
  }
}
