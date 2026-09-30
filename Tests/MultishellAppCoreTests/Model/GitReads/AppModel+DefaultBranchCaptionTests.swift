import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelDefaultBranchCaptionTests {
  @Test func theCaptionNamesTheDetectedBranchAndSaysSoWhenThereIsNone() {
    let h = Harness()
    #expect(
      h.model.defaultBranchCaption(for: h.project)
        == "No branch to measure merges against, so no worktree is badged as merged.")

    h.model.defaultBranches[h.project.id] = DefaultBranch(
      shortName: "origin/trunk", nameWithoutRemote: "trunk", tip: "abc",
      fullName: "refs/remotes/origin/trunk")

    #expect(
      h.model.defaultBranchCaption(for: h.project) == "Merges are measured against origin/trunk.")
  }
}
