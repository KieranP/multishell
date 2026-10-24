import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AutoRenameChoiceTests {
  private static func resolve(
    agent: String? = nil,
    model: String? = nil,
    effort: String? = nil,
    projectAgent: String? = "claude",
  ) -> AutoRenameChoice? {
    AutoRenameChoice.resolve(
      renameAgentID: agent,
      model: model,
      effort: effort,
      projectAgentID: projectAgent,
    )
  }

  @Test func theChosenAgentRunsAtTheChosenModelAndEffort() {
    let chosen = Self.resolve(agent: "codex", model: "gpt-6-luna", effort: "high")
    #expect(chosen?.agent.id == "codex")
    #expect(chosen?.model == "gpt-6-luna" && chosen?.effort == "high")
  }

  @Test func withNoRenameAgentTheProjectsAgentRunsAtItsOwnDefaults() {
    let fallback = Self.resolve(model: "haiku", effort: "low", projectAgent: "gemini")
    #expect(fallback?.agent.id == "gemini")
    #expect(fallback?.model == nil && fallback?.effort == nil)
  }

  @Test func aCustomCommandOrNoAgentHasNothingToRun() {
    #expect(Self.resolve(projectAgent: AgentCatalogue.customID) == nil)
    #expect(Self.resolve(projectAgent: nil) == nil)
    #expect(Self.resolve(agent: "future-agent") == nil, "a newer build's pick is not guessed at")
  }

  @Test func aModelOrEffortTheCatalogueDoesNotListGoesUnpassed() {
    let unknownModel = Self.resolve(agent: "claude", model: "claude-2", effort: "low")
    #expect(unknownModel?.model == nil)
    #expect(unknownModel?.effort == "low", "the default model takes low")
    let unknownEffort = Self.resolve(agent: "codex", model: "gpt-5.5", effort: "ultra")
    #expect(unknownEffort?.model == "gpt-5.5" && unknownEffort?.effort == nil)
  }

  @Test func anAgentWithNoEffortFlagIsHandedNone() {
    #expect(Self.resolve(agent: "gemini", model: "flash", effort: "high")?.effort == nil)
  }
}
