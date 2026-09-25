import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelSessionReportsTests {
  /// The board and the sidebar's Agents row are drawn from `reportedAgents`,
  /// and an agent reports twice per tool call, so an idle write renders both.
  @Test func aReportSayingWhatTheLastOneSaidWritesNothing() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    let session = tab.focusedSessionID
    func report() {
      h.model.apply(
        SessionStateReport(
          state: .running, sessionID: session, pid: 4242, agent: AgentCatalogue.claudeID))
    }
    report()

    let wrote = Flag()
    withObservationTracking {
      _ = h.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    report()

    #expect(!wrote.raised, "the same agent and pid again")
    #expect(h.model.reportedAgents[session]?.agentID == AgentCatalogue.claudeID)

    withObservationTracking {
      _ = h.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    h.model.apply(
      SessionStateReport(state: .running, sessionID: session, pid: 99, agent: "codex"))
    #expect(wrote.raised, "a different agent still lands")
  }
}
