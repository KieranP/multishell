import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelDefaultBranchTests {
  @Test func theCaptionNamesTheDetectedBranchAndSaysSoWhenThereIsNone() {
    let harness = Harness()
    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "No branch to measure merges against, so no worktree is badged as merged.")

    harness.model.defaultBranches[harness.project.id] = DefaultBranch(
      shortName: "origin/trunk", nameWithoutRemote: "trunk", tip: "abc",
      fullName: "refs/remotes/origin/trunk")

    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "Merges are measured against origin/trunk.")
  }

  @Test func theDefaultBranchFieldShowsTheDetectedBranchWithoutItsRemote() {
    let harness = Harness()
    #expect(harness.model.defaultBranchName(of: harness.project) == "main", "nothing detected yet")

    harness.model.defaultBranches[harness.project.id] = DefaultBranch(
      shortName: "origin/trunk", nameWithoutRemote: "trunk", tip: "abc",
      fullName: "refs/remotes/origin/trunk")

    #expect(harness.model.defaultBranchName(of: harness.project) == "trunk")
  }
}
