import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ResumingAgentTests {
  private let a = UUID()

  private func report(
    _ states: inout SessionStates, _ state: SessionState, _ subagent: SubagentReport? = nil,
    shells: [Int32] = [], startsTurn: Bool = false
  ) -> SessionState? {
    states.report(
      state, pid: 99, subagent: subagent, startsTurn: startsTurn, backgroundShells: shells,
      resumesAfterWorkers: state == .done, for: .session(a), isSeen: false)
  }

  private func shellGone(_ states: inout SessionStates, _ pid: Int32) -> [SessionState?] {
    states.endings(ofShell: pid).map {
      states.report(.running, pid: nil, subagent: $0.report, for: $0.key, isSeen: false)
    }
  }

  @Test func theWokenTurnsStopPaysTheDoneRatherThanTheLastShellOut() {
    var states = SessionStates()
    var meant = [report(&states, .done, shells: [500])]
    meant += shellGone(&states, 500)
    #expect(states[.session(a)] == .running, "the agent is about to take the result")
    #expect(states.keysAwaitingResume == [.session(a)])

    meant.append(report(&states, .running))
    meant.append(report(&states, .done))
    #expect(states[.session(a)] == .done)
    #expect(meant.filter { $0 == .done }.count == 1, "announced once, at the woken turn's end")
    #expect(states.keysAwaitingResume.isEmpty)
  }

  @Test func aWokenTurnThatOnlyStopsStillPaysOnce() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    #expect(shellGone(&states, 500) == [nil])
    #expect(report(&states, .done) == .done)
    #expect(states.keysAwaitingResume.isEmpty)
  }

  @Test func theLastSubagentOutAwaitsTheTurnItsEndStarts() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(report(&states, .done) == .running)
    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running)
    #expect(states.keysAwaitingResume == [.session(a)])
  }

  @Test func aResumeThatNeverComesIsPaidWhenOverdue() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    #expect(states.payOverdueResume(.session(a), isSeen: false) == .done)
    #expect(states[.session(a)] == .done)
    #expect(states.keysAwaitingResume.isEmpty)
    #expect(states.payOverdueResume(.session(a), isSeen: false) == nil, "paid once")
  }

  @Test func aResumeThatCameIsNotPaidAgainWhenItsTimeRunsOut() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    _ = report(&states, .running)
    #expect(states.payOverdueResume(.session(a), isSeen: false) == nil)
    #expect(states[.session(a)] == .running)
  }

  /// Hooks cross the socket in any order, so the woken turn's subagent can be
  /// heard from before the main thread's own tool call.
  @Test func aWorkerOutWhileAwaitingHoldsTheDoneUntilItEnds() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    _ = report(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(states.payOverdueResume(.session(a), isSeen: false) == nil, "w2 is still working")
    #expect(states[.session(a)] == .running)

    #expect(report(&states, .running, SubagentReport(id: "w2", phase: .ended)) == nil)
    #expect(states.keysAwaitingResume == [.session(a)], "awaiting the turn w2's end starts")
  }

  @Test func aPromptWhileAwaitingStartsATurnOfItsOwn() {
    var states = SessionStates()
    _ = report(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    #expect(report(&states, .running, startsTurn: true) == .running)
    #expect(states.keysAwaitingResume.isEmpty)
  }

  @Test func anAgentThatDoesNotResumeIsPaidByTheLastWorkerOut() {
    var states = SessionStates()
    states.report(.done, pid: 99, backgroundShells: [500], for: .session(a), isSeen: false)
    #expect(shellGone(&states, 500) == [.done])
    #expect(states.keysAwaitingResume.isEmpty)
  }
}
