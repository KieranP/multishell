import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentCatalogueDisplayNameTests {
  @Test func catalogueIdsBecomeNamesAndUnknownOnesStayAsTyped() {
    #expect(AgentCatalogue.displayName("claude") == "Claude Code")
    #expect(AgentCatalogue.displayName("custom") == "Custom command")
    #expect(AgentCatalogue.displayName("future") == "future")
  }
}
