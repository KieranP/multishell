import Foundation
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugLocationTests {
  @Test func aDirectoryInNoWorktreeIsNamedByItsLastComponentWithNoProject() {
    let harness = Harness()
    let location = harness.model.debugLocation(
      ofDirectory: URL(fileURLWithPath: "/elsewhere/scratch-repo"),
      in: harness.model.worktreesByStandardizedPath())

    #expect(location == DebugLocation(projectName: nil, worktreeName: "scratch-repo"))
  }

  @Test func aWorktreesRootIsNamedByItsProjectAndDisplayName() {
    let harness = Harness()
    let location = harness.model.debugLocation(
      ofDirectory: harness.feature.path.appendingPathComponent("."),
      in: harness.model.worktreesByStandardizedPath())

    #expect(
      location
        == DebugLocation(
          projectName: harness.project.name,
          worktreeName: harness.model.displayName(of: harness.feature)))
  }
}
