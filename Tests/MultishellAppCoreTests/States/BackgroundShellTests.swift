import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct BackgroundShellTests {
  private let a = UUID()

  private func stop(_ states: inout SessionStates, shells: [Int32]) -> SessionState? {
    states.report(.done, pid: 99, backgroundShells: shells, for: .session(a), isSeen: false)
  }

  private func shellGone(_ states: inout SessionStates, _ pid: Int32) -> [SessionState?] {
    states.endings(ofShell: pid).map {
      states.report(.running, pid: nil, subagent: $0.report, for: $0.key, isSeen: false)
    }
  }

  @Test func aStopWithAShellStillRunningIsHeldUntilTheShellIsGone() {
    var states = SessionStates()
    #expect(stop(&states, shells: [500]) == .running, "the task is still working")
    #expect(states[.session(a)] == .running)
    #expect(states.subagents(.session(a)).map(\.pid) == [500])
    #expect(states.trackedPIDs.contains(500), "polled like the agent's own pid")

    #expect(shellGone(&states, 500) == [.done], "the last one out pays the Done")
    #expect(states[.session(a)] == .done)
    #expect(states.subagents(.session(a)).isEmpty)
    #expect(!states.trackedPIDs.contains(500))
  }

  @Test func aShellNamedByTwoStopsIsOneWorkerAndEndsOnce() {
    var states = SessionStates()
    _ = stop(&states, shells: [500])
    _ = states.report(.running, pid: 99, for: .session(a), isSeen: false)
    #expect(stop(&states, shells: [500, 501]) == .running)
    #expect(states.subagents(.session(a)).workerCount == 2)

    #expect(shellGone(&states, 500) == [.running])
    #expect(shellGone(&states, 501) == [.done])
    #expect(shellGone(&states, 501).isEmpty, "nothing left to end")
  }

  @Test func aShellIsNotASubagentsNameAndSaysWhatItIs() {
    var states = SessionStates()
    _ = stop(&states, shells: [500])
    let shell = states.subagents(.session(a)).first
    #expect(shell?.type == nil)
    #expect(shell?.displayName == "background shell")
  }

  @Test func anotherKeysShellEndingMovesNothingHere() {
    var states = SessionStates()
    _ = stop(&states, shells: [500])
    #expect(shellGone(&states, 600).isEmpty)
    #expect(states[.session(a)] == .running)
  }
}
