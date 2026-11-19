import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelHandoffRecipientsTests {
  @Test func theAgentFocusedLastIsWhereASendGoesUnlessOneIsPicked() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.openTab(in: harness.main.id, title: "claude", agentID: AgentCatalogue.claudeID)
    harness.store.openTab(in: harness.main.id, title: "codex", agentID: AgentCatalogue.codexID)
    harness.model.reconcileSessions(takingFocus: true)
    let agents = harness.model.workspace.sessions(in: harness.main.id).filter { $0.agentID != nil }
    let claude = agents[0].id
    let codex = agents[1].id

    harness.model.reconciler.terminalHost(harness.engine, didFocus: codex)
    harness.model.reconciler.terminalHost(harness.engine, didFocus: claude)
    #expect(harness.model.handoffRecipient(in: harness.main.id)?.id == claude)

    harness.model.pickHandoffRecipient(codex, in: harness.main.id)
    #expect(harness.model.handoffRecipient(in: harness.main.id)?.id == codex)
  }
}
