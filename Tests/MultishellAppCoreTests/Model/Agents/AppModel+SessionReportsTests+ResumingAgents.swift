import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelSessionReportsTests {
  @Test func aStopHeldForABackgroundShellIsPaidAndAnnouncedWhenTheShellExits() async throws {
    let h = Harness()
    h.model.pidPollInterval = .milliseconds(50)
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier

    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", "read line"]
    let input = Pipe()
    shell.standardInput = input
    try shell.run()
    defer { shell.terminate() }

    h.stateSource.send(
      SessionStateReport(state: .running, sessionID: session, pid: me, agentID: "claude"))
    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude",
        backgroundShells: [shell.processIdentifier]))
    #expect(h.model.state(ofPane: session) == .running, "the shell is still working")
    #expect(h.model.subagents(ofPane: session).count == 1)
    #expect(h.notifier.posted.isEmpty)

    try input.fileHandleForWriting.close()
    shell.waitUntilExit()
    try await waitUntil({ h.model.state(ofPane: session) == .done }, seconds: 4)
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.model.subagents(ofPane: session).isEmpty)
    #expect(h.notifier.posted.count == 1, "the Done announced once, at the end")
  }

  @Test func aShellExitingBeforeTheWokenTurnAnnouncesOnlyThatTurnsStop() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = deadPID()

    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    h.model.sweepGonePIDs()
    #expect(h.model.state(ofPane: session) == .running, "waiting on the turn the exit starts")
    #expect(h.notifier.posted.isEmpty)

    h.stateSource.send(SessionStateReport(state: .running, sessionID: session, agentID: "claude"))
    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }

  @Test func aWokenTurnStoppingBeforeThePollSeesItsShellGoIsStillDone() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = deadPID()

    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [],
        resumesAfterWorkers: true))
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.model.subagents(ofPane: session).isEmpty)
    #expect(h.notifier.posted.count == 1)
  }

  @Test func aSubagentStartLandingAfterTheStopTakesBackThatDoneAndLeavesOneStanding() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID

    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    #expect(h.notifier.withdrawn.count == 1, "the Done was not true")
    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", phase: .ended)))
    #expect(h.model.state(ofPane: session) == .running)
    #expect(h.notifier.posted.count == 1)

    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 2)
    #expect(h.notifier.withdrawn.count == 1)
  }

  @Test func aStopListingABackgroundSubagentAnnouncesNothingUntilTheStopListingNone() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    func stop(_ out: [String]) {
      h.stateSource.send(
        SessionStateReport(
          state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true,
          workersOut: out.map { SubagentReport(id: $0, type: "Explore", phase: .working) }))
    }

    stop(["w1"])
    #expect(h.model.state(ofPane: session) == .running)
    #expect(h.model.subagents(ofPane: session).map(\.id) == ["w1"], "its start not heard yet")
    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", phase: .ended)))
    #expect(h.model.state(ofPane: session) == .running)
    #expect(h.notifier.posted.isEmpty)

    stop([])
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }

  @Test func aSubagentEndingBeforeTheWokenTurnAnnouncesOnlyThatTurnsStop() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", phase: .ended)))
    #expect(h.model.state(ofPane: session) == .running, "the woken turn is still writing")
    #expect(h.notifier.posted.isEmpty)

    h.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }
}
