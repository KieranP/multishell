import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelPIDWatchTests {
  @Test func aReportedProcessThatExitsClearsWorking() async throws {
    let h = Harness()
    h.model.pidPollInterval = .milliseconds(50)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let gone = deadPID()

    h.stateSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: gone))
    #expect(h.model.state(of: tab) == .running)
    #expect(h.model.pidWatch != nil)

    try await waitUntil({ h.model.state(of: tab) == nil }, seconds: 4)
    #expect(h.model.state(of: tab) == nil, "the agent was killed without a Stop hook")
    #expect(h.model.pidWatch == nil, "nothing left to watch")
  }

  @Test func aReportedProcessStillRunningKeepsItsStateThroughASweep() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let agent = Process()
    agent.executableURL = URL(fileURLWithPath: "/bin/sh")
    agent.arguments = ["-c", "read line"]
    let input = Pipe()
    agent.standardInput = input
    try agent.run()
    defer {
      agent.terminate()
      agent.waitUntilExit()
    }

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: tab.focusedSessionID, pid: agent.processIdentifier))
    h.model.sweepGonePIDs()

    #expect(h.model.watchedPIDs.contains(agent.processIdentifier))
    #expect(h.model.state(of: tab) == .running)
  }

  /// Whether the agent or its shell is checked first is a set's order, so
  /// several pairs make sure both orders are met.
  @Test func anAgentDyingWithItsShellAnnouncesNothingWhicheverIsSweptFirst() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    for _ in 0..<12 {
      let agent = deadPID()
      let shell = deadPID()
      h.stateSource.send(SessionStateReport(state: .running, sessionID: session, pid: agent))
      h.stateSource.send(
        SessionStateReport(
          state: .done, sessionID: session, pid: agent, backgroundShells: [shell]))
      h.model.sweepGonePIDs()
      #expect(h.model.state(ofPane: session) == nil, "agent \(agent), shell \(shell)")
    }
    #expect(h.notifier.posted.isEmpty)
  }
}
