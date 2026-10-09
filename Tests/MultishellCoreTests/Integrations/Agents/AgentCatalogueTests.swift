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

  @Test func eachAgentIsHandedItsTaskTheWayItsHelpSaysAnInteractiveSessionTakesOne() {
    let task = { AgentCatalogue.agent($0)?.taskArgument }
    #expect(task("claude") == .operand)
    #expect(task("codex") == .operand)
    #expect(task("gemini") == .option("--prompt-interactive"))
    #expect(task("copilot") == .option("--interactive"))
    #expect(task("opencode") == .option("--prompt"))
  }

  @Test func idsAreUniqueAndReserved() {
    let ids = AgentCatalogue.agents.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(!ids.contains(AgentCatalogue.noneID) && !ids.contains(AgentCatalogue.customID))
  }

  /// A dropped file is named to the agent the way its prompt reads one;
  /// the catalogue says so only where that is known.
  @Test func theCatalogueSaysWhichAgentsReadFileMentions() {
    #expect(AgentCatalogue.agent("claude")?.fileMentionPrefix == "@")
    #expect(AgentCatalogue.agent("codex")?.fileMentionPrefix == nil)
  }

  @Test func everyCatalogueAgentHasAMarkAndAParsableTint() {
    for agent in AgentCatalogue.agents {
      #expect(AgentCatalogue.mark(agent.id) == agent.mark)
      guard agent.markTint != nil else { continue }
      #expect(
        AgentCatalogue.markTintRGB(agent.id) != nil,
        "\(agent.id) names a tint the hex parser rejects")
    }
  }

  @Test func anAgentWithNoMarkOfItsOwnFallsBackToLetters() {
    #expect(AgentCatalogue.mark(AgentCatalogue.customID) == .monogram("Cc"))
  }

  /// A workspace written by a newer build names agents this one has never
  /// heard of; the tab still has to draw something.
  @Test func anUnknownIdGetsLettersFromTheIdItself() {
    #expect(AgentCatalogue.mark("wezterm-agent") == .monogram("Wa"))
    #expect(AgentCatalogue.markTintRGB("wezterm-agent") == nil)
  }
}
