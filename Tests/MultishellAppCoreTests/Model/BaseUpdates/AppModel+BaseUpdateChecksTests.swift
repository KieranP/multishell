import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelBaseUpdateChecksTests {
  @Test func theWorkingAgentIsNamedForTheOneThatReportedNotTheOneTheTabOpenedAs() throws {
    let harness = Harness()
    harness.model.setPreferredAgent("claude")
    harness.model.select(harness.main)
    harness.model.newAgentTab()
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, agentID: "codex")
    )

    #expect(
      harness.model.workingAgentName(in: harness.main.id)
        == harness.model.agentDisplayName("codex")
    )
  }
}
