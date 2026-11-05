import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelOverrideGlobalValuesTests {
  @Test func theDefaultBranchColumnNamesWhatDetectionFindsBesideTheProjectsOverride() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    _ = try await harness.git.run(["branch", "develop"], in: harness.project.path)
    harness.model.setSettings(ProjectSettings(defaultBranch: "develop"), for: harness.project)

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.defaultBranchName(of: harness.project) == "develop")
    #expect(
      harness.model.defaultBranchGlobalValue(for: harness.project).text == "Detected: main"
    )
  }

  @Test func theDefaultBranchColumnStillNamesTheDetectedBranchWhenTheOverrideMatchesNone()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    harness.model.setSettings(ProjectSettings(defaultBranch: "mian"), for: harness.project)

    await harness.model.refreshBranchScan(of: harness.project)

    #expect(
      harness.model.defaultBranchGlobalValue(for: harness.project).text == "Detected: main"
    )
  }

  @Test func theDefaultBranchColumnSaysItIsStillDetectingBeforeTheFirstScan() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    harness.model.defaultBranchScans[harness.project.id] = nil

    #expect(harness.model.defaultBranchGlobalValue(for: harness.project).text == "Detecting…")
  }
}
