import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ProjectSettingsEffectiveWorktreeSettingsTests {
  private let defaults = WorktreeSettings.globalDefaults

  @Test func nilFieldsFallBackToTheGlobalDefaults() {
    let effective = ProjectSettings().effectiveWorktreeSettings(defaults: defaults)
    #expect(effective == defaults)
  }

  @Test func eachFieldOverridesIndependently() {
    let effective = ProjectSettings(branchPrefix: "kieran/").effectiveWorktreeSettings(
      defaults: defaults
    )
    #expect(effective.worktreeDirectory == "/global/trees")
    #expect(effective.branchPrefix == "kieran/")

    let moved = ProjectSettings(worktreeDirectory: "../mine").effectiveWorktreeSettings(
      defaults: defaults
    )
    #expect(moved.worktreeDirectory == "../mine")
    #expect(moved.branchPrefix == defaults.branchPrefix)
  }

  @Test func aWhitespaceOverrideMeansNone() {
    // The sheet stores a lone space to opt a project out of a global
    // prefix; it must not end up in the branch name.
    let effective = ProjectSettings(branchPrefix: " ").effectiveWorktreeSettings(defaults: defaults)
    #expect(effective.branchPrefix == "")
    #expect(effective.qualifiedBranch("tabs") == "tabs")
  }
}
