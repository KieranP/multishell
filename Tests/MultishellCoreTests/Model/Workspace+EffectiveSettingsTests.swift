import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Each setting resolves project-over-global; the forms edit the override, and every
/// reader goes through these.
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

  @Test func aProjectsFlagsOverrideTheGlobalOnesForItsAgent() {
    let project = Project(path: URL(fileURLWithPath: "/repos/a"))
    var workspace = Workspace()
    workspace.preferredAgentID = AgentCatalogue.claudeID
    workspace.agentFlags = ["claude": "--model opus", "codex": "--full-auto"]

    #expect(workspace.agentFlags(for: project, agent: "claude") == "--model opus")
    #expect(workspace.agentFlags(for: project, agent: "codex") == "--full-auto")
    #expect(workspace.agentFlags(for: project, agent: "opencode") == "", "nothing stored")

    let quiet = Project(path: project.path, settings: ProjectSettings(agentFlags: ""))
    #expect(quiet.settings.agentFlags != nil, "blank is an override, not an absent key")
    #expect(
      workspace.agentFlags(for: quiet, agent: "claude") == "",
      "a project can run the agent bare under a global that passes flags")

    let own = Project(path: project.path, settings: ProjectSettings(agentFlags: "--model haiku"))
    #expect(workspace.agentFlags(for: own, agent: "claude") == "--model haiku")
  }

  @Test func aWorkspaceResolvesAProjectsAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let optsOut = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(preferredAgentID: "none"))
    let overrides = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(preferredAgentID: "codex"))
    #expect(workspace.effectiveAgentID(for: follows) == "claude")
    #expect(workspace.effectiveAgentID(for: optsOut) == nil)
    #expect(workspace.effectiveAgentID(for: overrides) == "codex")
  }

  @Test func autoStartFollowsTheGlobalUnlessOverriddenAndNeedsAnAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let forcedOn = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(autoStartAgent: true))
    let forcedOff = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(autoStartAgent: false))
    let noAgent = Project(
      path: URL(fileURLWithPath: "/d"),
      settings: ProjectSettings(preferredAgentID: "none", autoStartAgent: true))

    #expect(!workspace.autoStartsAgent(for: follows), "global off")
    #expect(workspace.autoStartsAgent(for: forcedOn))
    #expect(!workspace.autoStartsAgent(for: noAgent), "nothing to start")

    workspace.autoStartAgent = true
    #expect(workspace.autoStartsAgent(for: follows))
    #expect(!workspace.autoStartsAgent(for: forcedOff))
  }

  @Test func autoStartOnCreationIsAskedApartFromAutoStartOnTabOpen() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    workspace.autoStartAgentOnCreate = true
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let forcedOff = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(autoStartAgentOnCreate: false))
    let noAgent = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(preferredAgentID: "none"))

    #expect(workspace.autoStartsAgentOnCreate(for: follows))
    #expect(!workspace.autoStartsAgent(for: follows), "the tab-open setting is still off")
    #expect(!workspace.autoStartsAgentOnCreate(for: forcedOff))
    #expect(!workspace.autoStartsAgentOnCreate(for: noAgent), "nothing to start")
  }

  @Test func aWorkspaceResolvesAProjectsShellThroughItsOverride() {
    var workspace = Workspace()
    workspace.preferredShellID = "/bin/bash"
    let plain = Project(path: URL(fileURLWithPath: "/repos/a"))
    let fish = Project(
      path: URL(fileURLWithPath: "/repos/b"),
      settings: ProjectSettings(preferredShellID: "/usr/local/bin/fish"))
    let login = Project(
      path: URL(fileURLWithPath: "/repos/c"),
      settings: ProjectSettings(preferredShellID: ShellCatalogue.loginShellID))
    #expect(workspace.effectiveShellPath(for: plain) == "/bin/bash")
    #expect(workspace.effectiveShellPath(for: fish) == "/usr/local/bin/fish")
    #expect(workspace.effectiveShellPath(for: login) == nil)

    workspace.preferredShellID = ShellCatalogue.customID
    workspace.customShellPath = "/opt/homebrew/bin/nu"
    #expect(workspace.effectiveShellPath(for: plain) == "/opt/homebrew/bin/nu")
    #expect(workspace.effectiveShellPath(for: fish) == "/usr/local/bin/fish")
  }
}
