import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelProjectWorktreeCaptionsTests {
  @Test func theCaptionsSayWhereTheGlobalDirectoryAndPrefixPutAProjectsWorktree() {
    let harness = Harness()
    harness.model.setWorktreeDefaults(
      WorktreeSettings(worktreeDirectory: "/trees/{project}", branchPrefix: "team/")
    )
    let name = harness.project.name

    #expect(
      harness.model.worktreeContainerCaption(for: harness.project, isOverridden: false)
        == "Resolves to /trees/\(name)."
    )
    #expect(
      harness.model.branchPrefixCaption(for: harness.project, isOverridden: false)
        == "Typing tabs creates team/tabs at /trees/\(name)/team-tabs."
    )
  }
}
