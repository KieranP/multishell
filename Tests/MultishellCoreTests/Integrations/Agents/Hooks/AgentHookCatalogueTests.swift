import Testing

@testable import MultishellCore

@Suite
struct AgentHookCatalogueTests {
  @Test func everyIntegrationIsAnAgentTheCatalogueKnows() {
    for integration in AgentHookCatalogue.integrations {
      #expect(AgentCatalogue.agent(integration.id) != nil, "\(integration.id) is not launchable")
      #expect(AgentHookCatalogue.integration(integration.id)?.name == integration.name)
    }
    #expect(AgentHookCatalogue.integration("nonesuch") == nil)
    #expect(
      AgentHookCatalogue.integrations.map(\.id) == [
        "claude", "codex", "gemini", "copilot", "opencode",
      ])
  }
}
