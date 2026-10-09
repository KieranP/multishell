import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension AppModelSessionReportsTests {
  /// The board and the sidebar's Agents row are drawn from `reportedAgents`,
  /// and an agent reports twice per tool call, so an idle write renders both.
  @Test func aReportSayingWhatTheLastOneSaidWritesNothing() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    let session = tab.focusedSessionID
    func report() {
      harness.model.receive(
        SessionStateReport(
          state: .running,
          sessionID: session,
          pid: 4242,
          agentID: AgentCatalogue.claudeID,
        )
      )
    }
    report()

    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    report()

    #expect(!wrote.raised, "the same agent and pid again")
    #expect(harness.model.reportedAgents[session]?.agentID == AgentCatalogue.claudeID)

    withObservationTracking {
      _ = harness.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    harness.model.receive(
      SessionStateReport(state: .running, sessionID: session, pid: 99, agentID: "codex")
    )
    #expect(wrote.raised, "a different agent still lands")
  }
}
