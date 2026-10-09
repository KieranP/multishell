import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelPIDWatchTests {
  @Test func aReportedProcessThatExitsClearsWorking() async throws {
    let harness = Harness()
    harness.model.pidPollInterval = .milliseconds(50)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let gone = deadPID()

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: gone)
    )
    #expect(harness.model.state(of: tab) == .running)
    #expect(harness.model.pidWatch != nil)

    try await waitUntil({ harness.model.state(of: tab) == nil }, seconds: 4)
    #expect(harness.model.state(of: tab) == nil, "the agent was killed without a Stop hook")
    #expect(harness.model.pidWatch == nil, "nothing left to watch")
  }

  @Test func aReportedProcessStillRunningKeepsItsStateThroughASweep() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let agent = try WaitingShell()
    defer { agent.terminate() }

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: tab.focusedSessionID,
        pid: agent.pid,
      )
    )
    harness.model.sweepGonePIDs()

    #expect(harness.model.watchedPIDs.contains(agent.pid))
    #expect(harness.model.state(of: tab) == .running)
  }

  /// Whether the agent or its shell is checked first is a set's order, so
  /// several pairs make sure both orders are met.
  @Test func anAgentDyingWithItsShellAnnouncesNothingWhicheverIsSweptFirst() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    for _ in 0..<12 {
      let agent = deadPID()
      let shell = deadPID()
      harness.stateSource.send(SessionStateReport(state: .running, sessionID: session, pid: agent))
      harness.stateSource.send(
        SessionStateReport(
          state: .done,
          sessionID: session,
          pid: agent,
          backgroundShells: [shell],
        )
      )
      harness.model.sweepGonePIDs()
      #expect(harness.model.state(ofPane: session) == nil, "agent \(agent), shell \(shell)")
    }
    #expect(harness.notifier.posted.isEmpty)
  }
}
