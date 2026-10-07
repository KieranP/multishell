import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
@MainActor
struct AppModelDockBadgeTests {
  @Test func theBadgeCountsTheWaitingColumnAndClearsWithIt() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    // With the board up rather than the pane: a Failed about a pane the user
    // is looking at has been seen already and never reaches a column.
    model.showAgentBoard()
    harness.platform.badges.removeAll()

    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: session.id, agentID: "claude"))
    #expect(harness.platform.badges.last == 1)

    harness.stateSource.send(
      SessionStateReport(state: .failed, sessionID: session.id, agentID: "claude"))
    #expect(model.agentBoard.count(of: .waiting) == 1)
    #expect(harness.platform.badges == [1], "one waiting, still")

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude"))
    #expect(harness.platform.badges.last == .some(nil), "nothing waiting is no badge at all")
  }

  @Test func theBadgeFollowsTheFilter() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    model.showAgentBoard()
    harness.platform.badges.removeAll()

    harness.stateSource.send(SessionStateReport(state: .failed, sessionID: session.id))
    #expect(harness.platform.badges.isEmpty, "a shell, and shells are hidden")

    model.setShowsAllTerminals(true)
    #expect(harness.platform.badges.last == 1)
  }

  /// With the board closed no pid is polled, so the shell's own word that its
  /// command returned is what says the agent typed at that prompt has gone.
  @Test func aShellFailingAfterItsAgentQuitIsNotAnAgentWaitingOnTheBadge() {
    let (harness, session) = harnessWithOnePane()
    let model = harness.model
    model.select(harness.feature)
    harness.platform.badges.removeAll()

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: 1, agentID: "claude"))
    harness.stateSource.send(
      SessionStateReport(state: .idle, sessionID: session.id, agentID: "claude"))
    harness.engine.delegate?.terminalHost(
      harness.engine, didFinishCommandIn: session.id, exitCode: 0)
    #expect(model.reportedAgents[session.id] == nil, "the agent was the command that returned")

    harness.engine.delegate?.terminalHost(
      harness.engine, didFinishCommandIn: session.id, exitCode: 1)
    #expect(model.sessionStates[.session(session.id)] == .failed)
    #expect(model.agentLaneCounts[.waiting] ?? 0 == 0, "a shell's failure, and shells are hidden")
    #expect(harness.platform.badges.last != 1)
  }
}
