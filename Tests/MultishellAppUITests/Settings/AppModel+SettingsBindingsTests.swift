import MultishellAppCore
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

/// For a `Bool` setting `hasOverride` and `overrideValue` take the same arguments and
/// return the same type, so a swapped pair compiles. The form is an untested view.
@Suite @MainActor
struct AppModelSettingsBindingsTests {
  /// A swapped pair fails this: bound to `overrideValue`, ticking "override" would write
  /// `true` into the setting and the project would start auto-starting an agent.
  @Test func turningAnOverrideOnSeedsItWithWhatWasInForce() {
    let harness = ModelHarness()
    let project = harness.project
    #expect(harness.model.workspace.autoStartAgent == false, "the global this inherits from")

    let toggle = harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false)
    #expect(toggle.wrappedValue == false, "no override yet")

    toggle.wrappedValue = true
    #expect(
      harness.settings(of: project).autoStartAgent == false,
      "seeded with the inherited false, not with the toggle's own true")
    #expect(
      harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false).wrappedValue,
      "and the row now reads as overridden")
  }

  @Test func turningAnOverrideOffClearsItRatherThanStoringWhatWasShown() {
    let harness = ModelHarness()
    let project = harness.project
    harness.model.overrideValue(\.autoStartAgent, of: project, fallback: false).wrappedValue = true
    #expect(harness.settings(of: project).autoStartAgent == true)

    harness.model.hasOverride(\.autoStartAgent, of: project, fallback: false).wrappedValue = false
    #expect(
      harness.settings(of: project).autoStartAgent == nil,
      "off means follow the global, which is a nil override and not a stored false")
  }

  /// Blank would read as "this project has no worktree path", a different claim from
  /// "it uses the one you set globally".
  @Test func anOverrideThatIsOffShowsTheInheritedValue() {
    let harness = ModelHarness()
    let project = harness.project

    let field = harness.model.overrideValue(
      \.worktreeDirectory, of: project, fallback: "../inherited-worktrees")
    #expect(field.wrappedValue == "../inherited-worktrees")
    #expect(
      harness.settings(of: project).worktreeDirectory == nil,
      "reading the row stores nothing, so the project still follows")

    field.wrappedValue = "../its-own"
    #expect(harness.settings(of: project).worktreeDirectory == "../its-own")
  }

  /// A blank override is a value, not an absence: it is how "no prefix" is
  /// spelled while the global has one. The pair has to keep them apart.
  @Test func aBlankOverrideStaysAnOverride() {
    let harness = ModelHarness()
    let project = harness.project
    harness.model.setWorktreeDefaults(WorktreeSettings(branchPrefix: "team/"))

    let field = harness.model.overrideValue(\.branchPrefix, of: project, fallback: "team/")
    field.wrappedValue = ""
    #expect(harness.settings(of: project).branchPrefix == "")
    #expect(
      harness.model.hasOverride(\.branchPrefix, of: project, fallback: "team/").wrappedValue,
      "blank is still the project having its say")
    #expect(
      harness.model.worktreeSettings(for: harness.live).qualifiedBranch("tabs") == "tabs",
      "and the branch it would create carries no prefix")
  }

  /// A settings window outlives refreshes, so its `Project` goes stale; a binding that
  /// closed over it would write its settings back over anything changed meanwhile.
  @Test func aBindingFollowsTheRecordAndNotTheProjectItWasBuiltWith() {
    let harness = ModelHarness()
    let stale = harness.project

    // Something else changes the project while the window holds `stale`.
    harness.model.setExpanded(false, for: stale)
    harness.model.overrideValue(\.autoStartAgent, of: stale, fallback: false).wrappedValue = true

    #expect(
      harness.model.workspace.project(stale.id)?.isExpanded == false,
      "the change is not lost")
    #expect(harness.settings(of: stale).autoStartAgent == true, "and the write still landed")
  }
}
