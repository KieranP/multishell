import MultishellCore
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelDefaultBranchTests {
  @Test func theCaptionSaysTheBranchIsBeingFoundBeforeTheFirstScan() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    harness.model.defaultBranchScans[harness.project.id] = nil

    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "Finding the branch merges are measured against…"
    )
  }

  @Test func theCaptionMeasuresAgainstNothingWithoutGitToScanWith() {
    let harness = Harness()

    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "No branch to measure merges against, so no worktree is badged as merged."
    )
  }

  @Test func theCaptionOfAProjectWhoseFolderIsGoneMeasuresAgainstNothing() {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(.sample("main"))

    harness.model.missingProjects.insert(harness.project.id)

    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "No branch to measure merges against, so no worktree is badged as merged."
    )
  }

  @Test func theCaptionNamesTheDetectedBranchAndSaysSoWhenThereIsNone() {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent
    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "No branch to measure merges against, so no worktree is badged as merged."
    )

    harness.model.defaultBranchScans[harness.project.id] = .found(
      .sample("trunk", remote: "origin")
    )

    #expect(
      harness.model.defaultBranchCaption(for: harness.project)
        == "Merges are measured against origin/trunk."
    )
  }

  @Test func theDefaultBranchFieldShowsTheDetectedBranchWithoutItsRemote() {
    let harness = Harness()
    #expect(harness.model.defaultBranchName(of: harness.project) == "main", "nothing detected yet")

    harness.model.defaultBranchScans[harness.project.id] = .found(
      .sample("trunk", remote: "origin")
    )

    #expect(harness.model.defaultBranchName(of: harness.project) == "trunk")
  }
}
