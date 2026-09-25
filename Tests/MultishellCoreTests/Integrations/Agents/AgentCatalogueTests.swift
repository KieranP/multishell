import Foundation
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
    #expect(AgentCatalogue.effectiveID(global: nil, override: "codex") == "codex")
  }

  /// A resume spelled wrong reaches the pane as "unknown option", and the tab is a shell
  /// where a conversation was expected.
  @Test func theSupportedAgentsResumeTheirLastConversation() {
    let resume = { AgentCatalogue.agent($0)?.resumeArguments }
    #expect(resume("claude") == ["--continue"])
    #expect(resume("codex") == ["resume", "--last"])
    #expect(resume("gemini") == ["--resume", "latest"])
    #expect(resume("copilot") == ["--continue"])
    #expect(resume("opencode") == ["--continue"])
    #expect(resume("nonesuch") == nil, "an id the catalogue does not know is a shell")
  }

  @Test func idsAreUniqueAndReserved() {
    let ids = AgentCatalogue.agents.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(AgentCatalogue.noneID) && !ids.contains(AgentCatalogue.customID))
    #expect(AgentCatalogue.agent("claude")?.resumeArguments == ["--continue"])
    #expect(AgentCatalogue.agent("wezterm-agent") == nil)
  }

}
