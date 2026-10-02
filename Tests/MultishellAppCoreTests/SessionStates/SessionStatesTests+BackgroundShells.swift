import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

extension SessionStatesTests {
  @Test func aStopWithAShellStillRunningIsHeldUntilTheShellIsGone() {
    var states = SessionStates()
    #expect(
      report(&states, .init(state: .done, backgroundShells: [500])) == .running,
      "the task is still working")
    #expect(states[.session(a)] == .running)
    #expect(states.workers(.session(a)).map(\.pid) == [500])
    #expect(states.trackedPIDs.contains(500), "polled like the agent's own pid")

    #expect(states.applyShellExit(500) == [.done], "the last one out pays the Done")
    #expect(states[.session(a)] == .done)
    #expect(states.workers(.session(a)).isEmpty)
    #expect(!states.trackedPIDs.contains(500))
  }

  @Test func aShellNamedByTwoStopsIsOneWorkerAndEndsOnce() {
    var states = SessionStates()
    _ = report(&states, .init(state: .done, backgroundShells: [500]))
    _ = report(&states, .init(state: .running))
    #expect(report(&states, .init(state: .done, backgroundShells: [500, 501])) == .running)
    #expect(states.workers(.session(a)).workerCount == 2)

    #expect(states.applyShellExit(500) == [.running])
    #expect(states.applyShellExit(501) == [.done])
    #expect(states.applyShellExit(501).isEmpty, "nothing left to end")
  }

  @Test func aBackgroundShellHasNoSubagentTypeAndIsNamedForWhatItIs() {
    var states = SessionStates()
    _ = report(&states, .init(state: .done, backgroundShells: [500]))
    let shell = states.workers(.session(a)).first
    #expect(shell?.type == nil)
    #expect(shell?.displayName == "background shell")
  }

  @Test func aShellNobodyReportedEndingMovesNothing() {
    var states = SessionStates()
    _ = report(&states, .init(state: .done, backgroundShells: [500]))
    #expect(states.applyShellExit(600).isEmpty)
    #expect(states[.session(a)] == .running)
  }

  @Test func aStopNamingAsManyShellsAsTheWireCarriesKeepsEveryOne() {
    var states = SessionStates()
    _ = report(
      &states,
      .init(state: .done, backgroundShells: Array(1...Int32(SessionStateReport.rosterCapacity))))

    #expect(workersOut(states).count == SessionStateReport.rosterCapacity)
  }

  @Test func aStopNamingThousandsOfShellsKeepsNoMoreThanTheRosterHolds() {
    var states = SessionStates()
    var stop = SessionStateReport(state: .done)
    stop.backgroundShells = Array(1...5000)
    _ = report(&states, stop)

    #expect(workersOut(states).count <= SessionStateReport.rosterCapacity)
  }
}
