import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelGlobalAgentIDTests {
  @Test func theGlobalAgentIsNoneUntilOneIsChosen() {
    let h = Harness()
    #expect(h.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)

    h.model.setPreferredAgent("claude")

    #expect(h.model.globalAgentID == "claude")
    #expect(h.model.hasPreferredAgent)
  }

  @Test func aStoredNoneIsNoPreferredAgent() {
    let h = Harness()
    h.store.setPreferredAgent(AgentCatalogue.noneID)

    #expect(h.model.globalAgentID == AgentCatalogue.noneID)
    #expect(!h.model.hasPreferredAgent)
  }
}
