import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  private func report(
    _ states: inout SessionStates, _ state: SessionState, _ subagent: SubagentReport? = nil,
    shells: [Int32] = []
  ) -> SessionState? {
    states.report(
      state, pid: 99, subagent: subagent, backgroundShells: shells,
      resumesAfterWorkers: state == .done, for: .session(a), isSeen: false)
  }

  @Test func theWokenTurnsStopPaysTheDoneRatherThanTheLastShellOut() {
    var states = SessionStates()
    var meant = [report(&states, .done, shells: [500])]
    meant += shellGone(&states, 500)
    #expect(states[.session(a)] == .running, "the agent is about to take the result")

    meant.append(report(&states, .running))
    meant.append(report(&states, .done))
    #expect(states[.session(a)] == .done)
    #expect(meant.filter { $0 == .done }.count == 1, "announced once, at the woken turn's end")
  }

  @Test func aWokenTurnThatOnlyStopsStillPaysOnce() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    #expect(shellGone(&states, 500) == [nil])
    #expect(report(&states, .done) == .done)
  }

  @Test func theLastSubagentOutLeavesTheDoneToTheTurnItsEndStarts() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(report(&states, .done) == .running)
    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .done) == .done)
  }

  /// Hooks cross the socket in any order, so the woken turn's subagent can be
  /// heard from before the main thread's own tool call.
  @Test func aWorkerOutInTheWokenTurnLeavesItsStopToPay() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    #expect(report(&states, .running, SubagentReport(id: "w2", phase: .started)) == .running)
    #expect(report(&states, .running, SubagentReport(id: "w2", phase: .ended)) == .running)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .done) == .done)
  }

  @Test func aSubagentStartLandingAfterTheStopLeavesTheDoneToTheWokenTurn() {
    var states = SessionStates()
    #expect(report(&states, .done) == .done)
    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .started)) == .running)
    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .done) == .done)
  }

  private func stop(_ states: inout SessionStates, ended: [String]) -> SessionState? {
    states.report(
      .done, pid: 99, resumesAfterWorkers: true, endedWorkers: ended, for: .session(a),
      isSeen: false)
  }

  @Test func aWokenTurnsStopLandingBeforeItsSubagentStopPaysTheDone() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(stop(&states, ended: []) == .running)
    #expect(stop(&states, ended: ["w1"]) == .done, "its record says w1 has ended")
    #expect(states.subagents(.session(a)).isEmpty)

    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func aSubagentStoppedWithNoEndOfItsOwnHoldsNoStop() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(stop(&states, ended: ["w1", "someone-else"]) == .running, "w2 is still out")
    #expect(states.subagents(.session(a)).map(\.id) == ["w2"])
  }

  @Test func aStopsRecordTakesBackThePromptOfAWorkerItSaysEnded() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)
    #expect(stop(&states, ended: ["w1"]) == .done)
  }

  @Test func anAgentThatDoesNotResumeIsPaidByTheLastWorkerOut() {
    var states = SessionStates()
    states.report(.done, pid: 99, backgroundShells: [500], for: .session(a), isSeen: false)
    #expect(shellGone(&states, 500) == [.done])
  }
}
