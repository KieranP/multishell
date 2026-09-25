import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The two listing settings resolve project-over-global like the rest; the
/// forms edit the override, and every reader goes through these.
@Suite
struct WorkspaceEffectiveSettingsTests {
  private func project(
    order: WorktreeSortOrder? = nil, activeFirst: Bool? = nil
  ) -> Project {
    var project = Project(path: URL(fileURLWithPath: "/w/demo"))
    project.settings = ProjectSettings(
      worktreeSortOrder: order, showsActiveWorktreesFirst: activeFirst)
    return project
  }

  @Test func aProjectWithNoOverrideFollowsTheGlobal() {
    var workspace = Workspace()
    workspace.worktreeSortOrder = .createdOldestFirst
    workspace.showsActiveWorktreesFirst = true

    #expect(workspace.worktreeSortOrder(for: project()) == .createdOldestFirst)
    #expect(workspace.showsActiveWorktreesFirst(for: project()))
  }

  @Test func aProjectsOwnChoiceWins() {
    var workspace = Workspace()
    workspace.worktreeSortOrder = .createdOldestFirst
    workspace.showsActiveWorktreesFirst = true
    let overridden = project(order: .committedNewestFirst, activeFirst: false)

    #expect(workspace.worktreeSortOrder(for: overridden) == .committedNewestFirst)
    #expect(!workspace.showsActiveWorktreesFirst(for: overridden))
  }

  /// An override that says "off" is not the same as no override: without
  /// this, turning the global on would drag every project with it.
  @Test func anOverrideThatMatchesTheOldGlobalStillHolds() {
    var workspace = Workspace()
    let overridden = project(order: .alphabetical, activeFirst: false)
    workspace.worktreeSortOrder = .createdNewestFirst
    workspace.showsActiveWorktreesFirst = true

    #expect(workspace.worktreeSortOrder(for: overridden) == .alphabetical)
    #expect(!workspace.showsActiveWorktreesFirst(for: overridden))
  }

  @Test func theGlobalFlagsAreThoseOfTheAgentTheProjectRuns() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    workspace.agentFlags = ["claude": "--resume", "codex": "--yolo"]
    var project = project()

    #expect(workspace.globalAgentFlags(for: project) == "--resume")
    project.settings.preferredAgentID = "codex"
    #expect(workspace.globalAgentFlags(for: project) == "--yolo")
    project.settings.agentFlags = "--own"
    #expect(workspace.globalAgentFlags(for: project) == "--yolo", "its own line is not global")
  }

  @Test func noAgentOrNoLineForItHasNoGlobalFlags() {
    var workspace = Workspace()
    workspace.agentFlags = ["codex": "--yolo"]
    #expect(workspace.globalAgentFlags(for: project()).isEmpty)
    workspace.preferredAgentID = "claude"
    #expect(workspace.globalAgentFlags(for: project()).isEmpty)
  }
}
