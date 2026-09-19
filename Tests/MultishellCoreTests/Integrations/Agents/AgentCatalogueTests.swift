import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentCatalogueTests {
  @Test func theOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    #expect(AgentCatalogue.effectiveID(global: "claude", override: nil) == "claude")
    #expect(AgentCatalogue.effectiveID(global: "claude", override: "codex") == "codex")
    #expect(AgentCatalogue.effectiveID(global: "claude", override: "none") == nil)
    #expect(AgentCatalogue.effectiveID(global: nil, override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: "none", override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: "", override: nil) == nil)
    #expect(AgentCatalogue.effectiveID(global: nil, override: "aider") == "aider")
  }

  /// Each of the five the app supports first-hand resumes the way its own
  /// CLI spells it; one spelled wrong reaches the pane as "unknown option"
  /// and the tab is a shell where a conversation was expected.
  @Test func theSupportedAgentsResumeTheirLastConversation() {
    let resume = { AgentCatalogue.agent($0)?.resumeArguments }
    #expect(resume("claude") == ["--continue"])
    #expect(resume("codex") == ["resume", "--last"])
    #expect(resume("gemini") == ["--resume", "latest"])
    #expect(resume("copilot") == ["--continue"])
    #expect(resume("opencode") == ["--continue"])
    #expect(resume("aider") == nil, "no flag for it, so a saved tab is a shell")
  }

  @Test func idsAreUniqueAndReserved() {
    let ids = AgentCatalogue.agents.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(AgentCatalogue.noneID) && !ids.contains(AgentCatalogue.customID))
    #expect(AgentCatalogue.agent("claude")?.resumeArguments == ["--continue"])
    #expect(AgentCatalogue.agent("wezterm-agent") == nil)
  }

  @Test func aWorkspaceResolvesAProjectsAgent() {
    var workspace = Workspace()
    workspace.preferredAgentID = "claude"
    let follows = Project(path: URL(fileURLWithPath: "/a"))
    let optsOut = Project(
      path: URL(fileURLWithPath: "/b"), settings: ProjectSettings(preferredAgentID: "none"))
    let overrides = Project(
      path: URL(fileURLWithPath: "/c"), settings: ProjectSettings(preferredAgentID: "codex"))
    #expect(workspace.preferredAgentID(for: follows) == "claude")
    #expect(workspace.preferredAgentID(for: optsOut) == nil)
    #expect(workspace.preferredAgentID(for: overrides) == "codex")
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
}
