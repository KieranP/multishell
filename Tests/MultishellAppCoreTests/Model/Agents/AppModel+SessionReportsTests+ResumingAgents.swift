import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension AppModelSessionReportsTests {
  @Test func aStopHeldForABackgroundShellIsPaidAndAnnouncedWhenTheShellExits() async throws {
    let harness = Harness()
    harness.model.pidPollInterval = .milliseconds(50)
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier

    let shell = try WaitingShell()
    defer { shell.end() }

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session, pid: me, agentID: "claude"))
    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude",
        backgroundShells: [shell.pid]))
    #expect(harness.model.state(ofPane: session) == .running, "the shell is still working")
    #expect(harness.model.workers(ofPane: session).count == 1)
    #expect(harness.notifier.posted.isEmpty)

    try shell.finish()
    try await waitUntil({ harness.model.state(ofPane: session) == .done }, seconds: 4)
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.model.workers(ofPane: session).isEmpty)
    #expect(harness.notifier.posted.count == 1, "the Done announced once, at the end")
  }

  @Test func aShellExitingBeforeTheWokenTurnAnnouncesOnlyThatTurnsStop() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = deadPID()

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    harness.model.sweepGonePIDs()
    #expect(harness.model.state(ofPane: session) == .running, "waiting on the turn the exit starts")
    #expect(harness.notifier.posted.isEmpty)

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session, agentID: "claude"))
    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.notifier.posted.count == 1)
  }

  @Test func aWokenTurnStoppingBeforeThePollSeesItsShellGoIsStillDone() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = deadPID()

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agentID: "claude", backgroundShells: [],
        resumesAfterWorkers: true))
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.model.workers(ofPane: session).isEmpty)
    #expect(harness.notifier.posted.count == 1)
  }

  @Test func aSubagentStartLandingAfterTheStopTakesBackThatDoneAndLeavesOneStanding() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        worker: WorkerReport(id: "w1", type: "Explore", phase: .started)))
    #expect(harness.notifier.withdrawn.count == 1, "the Done was not true")
    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .ended)))
    #expect(harness.model.state(ofPane: session) == .running)
    #expect(harness.notifier.posted.count == 1)

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.notifier.posted.count == 2)
    #expect(harness.notifier.withdrawn.count == 1)
  }

  @Test func aStopListingABackgroundSubagentAnnouncesNothingUntilTheStopListingNone() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    func stop(_ out: [String]) {
      harness.stateSource.send(
        SessionStateReport(
          state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true,
          workersOut: out.map { WorkerReport(id: $0, type: "Explore", phase: .working) }))
    }

    stop(["w1"])
    #expect(harness.model.state(ofPane: session) == .running)
    #expect(harness.model.workers(ofPane: session).map(\.id) == ["w1"], "its start not heard yet")
    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .ended)))
    #expect(harness.model.state(ofPane: session) == .running)
    #expect(harness.notifier.posted.isEmpty)

    stop([])
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.notifier.posted.count == 1)
  }

  @Test func aSubagentEndingBeforeTheWokenTurnAnnouncesOnlyThatTurnsStop() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID

    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        worker: WorkerReport(id: "w1", type: "Explore", phase: .started)))
    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    harness.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .ended)))
    #expect(harness.model.state(ofPane: session) == .running, "the woken turn is still writing")
    #expect(harness.notifier.posted.isEmpty)

    harness.stateSource.send(
      SessionStateReport(
        state: .done, sessionID: session, agentID: "claude", resumesAfterWorkers: true))
    #expect(harness.model.state(ofPane: session) == .done)
    #expect(harness.notifier.posted.count == 1)
  }
}
