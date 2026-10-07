import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  private func reportResuming(
    _ states: inout SessionStates, _ state: SessionState, _ worker: WorkerReport? = nil,
    shells: [Int32] = [], out: [String]? = nil, startsTurn: Bool = false,
    conversation: String? = nil
  ) -> SessionState? {
    report(
      &states,
      .init(
        state: state, worker: worker, startsTurn: startsTurn, backgroundShells: shells,
        resumesAfterWorkers: state == .done, conversationID: conversation,
        workersOut: out.map { $0.map { WorkerReport(id: $0, phase: .working) } }))
  }

  @Test func theWokenTurnsStopPaysTheDoneRatherThanTheLastShellOut() {
    var states = SessionStates()
    var meant = [reportResuming(&states, .done, shells: [500])]
    meant += states.applyShellExit(500)
    #expect(states[.session(a)] == .running, "the agent is about to take the result")

    meant.append(reportResuming(&states, .running))
    meant.append(reportResuming(&states, .done))
    #expect(states[.session(a)] == .done)
    #expect(meant.filter { $0 == .done }.count == 1, "announced once, at the woken turn's end")
  }

  @Test func aWokenTurnThatOnlyStopsStillPaysOnce() {
    var states = SessionStates()
    _ = reportResuming(&states, .done, shells: [500])
    #expect(states.applyShellExit(500) == [nil])
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func theLastSubagentOutLeavesTheDoneToTheTurnItsEndStarts() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    #expect(reportResuming(&states, .running, ended("w1")) == nil)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  /// Hooks cross the socket in any order, so the woken turn's subagent can be
  /// heard from before the main thread's own tool call.
  @Test func aWorkerOutInTheWokenTurnLeavesItsStopToPay() {
    var states = SessionStates()
    _ = reportResuming(&states, .done, shells: [500])
    _ = states.applyShellExit(500)
    #expect(
      reportResuming(&states, .running, WorkerReport(id: "w2", phase: .started)) == .running)
    #expect(reportResuming(&states, .running, ended("w2")) == .running)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aSubagentStartLandingAfterTheStopLeavesTheDoneToTheWokenTurn() {
    var states = SessionStates()
    #expect(reportResuming(&states, .done) == .done)
    #expect(
      reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started)) == .running)
    #expect(reportResuming(&states, .running, ended("w1")) == nil)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  /// A Stop that lists what is still out, as Claude's `background_tasks` does.
  private func stopListingWorkersOut(
    _ states: inout SessionStates, out: [String], shells: [Int32] = []
  ) -> SessionState? {
    report(
      &states,
      .init(
        state: .done, backgroundShells: shells, resumesAfterWorkers: true,
        workersOut: out.map { WorkerReport(id: $0, phase: .working) }))
  }

  @Test func aStopListingNothingOutPaysTheDoneThoughAnEndNeverCame() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    #expect(stopListingWorkersOut(&states, out: ["w1"]) == .running)
    #expect(
      stopListingWorkersOut(&states, out: []) == .done, "w1's SubagentStop is late or never comes")
    #expect(states.workers(.session(a)).isEmpty)

    #expect(reportResuming(&states, .running, ended("w1")) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func aStopListingAWorkerWhoseStartHasNotLandedHoldsTheDone() {
    var states = SessionStates()
    #expect(stopListingWorkersOut(&states, out: ["w1"]) == .running)
    #expect(states.workers(.session(a)).map(\.id) == ["w1"])
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .working))
    #expect(
      reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started)) == .running)
    #expect(states.workers(.session(a)).first?.occurrences == 1, "the late start is w1's own")

    #expect(reportResuming(&states, .running, ended("w1")) == nil)
    #expect(states[.session(a)] == .running, "the turn w1's end wakes pays")
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  @Test func aStopKeepsOnlyTheWorkersItListsAndThoseAfterItByHook() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, WorkerReport(id: "w2", phase: .started))
    #expect(stopListingWorkersOut(&states, out: ["w2"]) == .running)
    #expect(states.workers(.session(a)).map(\.id) == ["w2"])
  }

  /// Claude 2.1.292 lists only background work, so a foreground worker a
  /// background one launched is out though its Stop leaves it off.
  @Test func aStopKeepsTheForegroundWorkerOfAWorkerItListsAndThatWorkersPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "review", phase: .started))
    _ = reportResuming(&states, .running, WorkerReport(id: "angle", phase: .started))
    _ = reportResuming(
      &states, .attention, WorkerReport(id: "angle", phase: .working, parentID: "review"))
    _ = stopListingWorkersOut(&states, out: ["review"])
    #expect(states.workers(.session(a)).map(\.id) == ["review", "angle"])
    #expect(states[.session(a)] == .attention)
  }

  @Test func aStopDropsAWorkerUnderOneItNoLongerLists() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "review", phase: .started))
    _ = reportResuming(
      &states, .running, WorkerReport(id: "angle", phase: .working, parentID: "review"))
    #expect(stopListingWorkersOut(&states, out: []) == .done)
    #expect(states.workers(.session(a)).isEmpty)
  }

  @Test func aStopListingNoShellDropsTheShellsAnEarlierStopLeft() {
    var states = SessionStates()
    #expect(stopListingWorkersOut(&states, out: [], shells: [500]) == .running)
    #expect(stopListingWorkersOut(&states, out: [], shells: [500]) == .running, "still listed")
    #expect(stopListingWorkersOut(&states, out: []) == .done, "gone before the poll saw it")
    #expect(states.workers(.session(a)).isEmpty)
  }

  @Test func aShellTheStopListsIsCountedAsAShellAndGoesWhenNoLongerListed() {
    var states = SessionStates()
    let shell = WorkerReport(id: "b1", phase: .working, isBackgroundShell: true)
    #expect(
      report(&states, .init(state: .done, resumesAfterWorkers: true, workersOut: [shell]))
        == .running)
    #expect(states.workers(.session(a)).countText == "1 background shell")
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  @Test func aStopTakesBackThePromptOfAWorkerItNoLongerLists() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    #expect(
      reportResuming(&states, .attention, WorkerReport(id: "w1", phase: .working)) == .attention)
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  private func cancelled(_ id: String) -> WorkerReport {
    WorkerReport(id: id, phase: .ended, wakesAgent: false)
  }

  @Test func aCancelledLastWorkerWakesNoTurnSoItsEndPaysTheDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    #expect(reportResuming(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aCancelledLastWorkerLeavesTheDoneToATurnAnEarlierEndWoke() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, WorkerReport(id: "w2", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    _ = reportResuming(&states, .running, ended("w1"))
    #expect(
      reportResuming(&states, .running, cancelled("w2")) == nil, "w1's end is about to wake it")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aCancelledLastWorkerAfterTheWokenTurnStoppedPaysTheDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, WorkerReport(id: "w2", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, ended("w1"))
    _ = reportResuming(&states, .running)
    #expect(reportResuming(&states, .done) == .running, "w2 is still out")
    #expect(reportResuming(&states, .running, cancelled("w2")) == .done)
  }

  @Test func aCancelledLastWorkerDuringTheWokenTurnLeavesTheDoneToThatTurnsStop() {
    var states = SessionStates()
    var meant: [SessionState?] = []
    meant.append(reportResuming(&states, .running, WorkerReport(id: "c1", phase: .started)))
    meant.append(reportResuming(&states, .running, WorkerReport(id: "c2", phase: .started)))
    meant.append(reportResuming(&states, .done, out: ["c1", "c2"]))
    meant.append(reportResuming(&states, .running, ended("c1")))
    meant.append(reportResuming(&states, .running))
    meant.append(reportResuming(&states, .running, cancelled("c2")))
    #expect(states[.session(a)] == .running, "the woken turn is still running")
    meant.append(reportResuming(&states, .done, out: []))
    #expect(meant.filter { $0 == .done }.count == 1)
  }

  @Test func aWorkerOutAtTheStopStaysOutAcrossTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, startsTurn: true, conversation: "P")
    _ = reportResuming(&states, .running, conversation: "C")
    #expect(reportResuming(&states, .done, conversation: "P") == .running)
    _ = reportResuming(&states, .running, startsTurn: true, conversation: "P")
    #expect(states.workers(.session(a)).map(\.id) == ["C"])
    #expect(reportResuming(&states, .done, conversation: "P") == .running, "C is still out")
  }

  @Test func aWorkerHeardOnlyInATurnThatNeverStoppedGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.workers(.session(a)).isEmpty, "an interrupt killed it and said nothing")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aStopWithANoticeStillQueuedLeavesTheDoneToTheTurnItStarts() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, ended("w1"))
    let held = report(
      &states, .init(state: .done, resumesAfterWorkers: true, workersOut: [], turnFollows: true))
    #expect(held == .running, "w1's notice starts a turn straight after")
    #expect(reportResuming(&states, .running) == .running)
    #expect(reportResuming(&states, .done, out: []) == .done)
  }

  @Test func aStopWithNothingQueuedAndNothingOutIsDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, ended("w1"))
    #expect(reportResuming(&states, .done, out: []) == .done)
  }

  @Test func aWorkerSilentSinceTheLastStopGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(reportResuming(&states, .done) == .running, "kept once: a Stop saw it out")
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.workers(.session(a)).isEmpty, "silent through a whole turn, its end lost")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aWorkerHeardFromInTheTurnStaysOutAcrossTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .working))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.workers(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aStrayEndForAWorkerNotOutWakesNoTurn() {
    var states = SessionStates()
    #expect(reportResuming(&states, .done, out: ["w2"]) == .running)
    _ = reportResuming(&states, .running, ended("w1"))
    #expect(reportResuming(&states, .running, cancelled("w2")) == .done, "nothing was woken for w2")
  }

  @Test func aStopOverAFailureStillMarksItsWorkersOut() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .failed)
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.workers(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aListedSubagentTakesItsKindFromItsStart() {
    var states = SessionStates()
    _ = report(
      &states,
      .init(
        state: .done, resumesAfterWorkers: true,
        workersOut: [WorkerReport(id: "w1", type: "subagent", phase: .working)]))
    _ = reportResuming(
      &states, .running, WorkerReport(id: "w1", type: "Explore", phase: .started))
    #expect(states.workers(.session(a)).first?.type == "Explore")
  }

  @Test func theAgentsOwnPromptWhileAStopIsHeldIsNoTurnUnderway() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .attention)
    #expect(reportResuming(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aStopListingEveryOneOfManyWorkersKeepsThemAll() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = reportResuming(&states, .running, WorkerReport(id: id, phase: .started)) }
    let listed = SessionStateReport(
      state: .done, resumesAfterWorkers: true,
      workersOut: ids.map { WorkerReport(id: $0, phase: .working) })
    _ = report(&states, listed)
    for id in ids.prefix(69) {
      _ = reportResuming(&states, .running, ended(id))
    }
    #expect(!states.workers(.session(a)).isEmpty, "w70 is still out")
  }

  @Test func aListCutAtItsLimitTakesNobodyOff() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, WorkerReport(id: "w0", phase: .started))
    let full = (1...SessionStateReport.maximumWorkersOut).map {
      WorkerReport(id: "l\($0)", phase: .working)
    }
    _ = report(&states, .init(state: .done, resumesAfterWorkers: true, workersOut: full))
    #expect(states.workers(.session(a)).contains { $0.id == "w0" }, "the cut may have held it")
  }

  @Test func aPromptKeepsTheWorkersOverflowedPastTheLimitThatAStopSawOut() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = reportResuming(&states, .running, WorkerReport(id: id, phase: .started)) }
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    for id in ids.prefix(69) {
      _ = reportResuming(&states, .running, ended(id))
    }
    #expect(reportResuming(&states, .done) == .running, "w70 is still out")
  }

  @Test func aShellEveryStopFindsAliveStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    for _ in 0..<3 {
      _ = report(&states, .init(state: .done, backgroundShells: [500]))
      _ = reportResuming(&states, .running, startsTurn: true)
      #expect(states.workers(.session(a)).map(\.pid) == [500], "the Stop found it running")
    }
  }

  @Test func aShellEveryListNamesStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    let shell = WorkerReport(id: "b1", phase: .working, isBackgroundShell: true)
    for _ in 0..<3 {
      _ = report(&states, .init(state: .done, resumesAfterWorkers: true, workersOut: [shell]))
      _ = reportResuming(&states, .running, startsTurn: true)
      #expect(states.workers(.session(a)).map(\.id) == ["b1"])
    }
  }

  @Test func anAgentThatDoesNotResumeIsPaidByTheLastWorkerOut() {
    var states = SessionStates()
    report(&states, .init(state: .done, backgroundShells: [500]))
    #expect(states.applyShellExit(500) == [.done])
  }
}
