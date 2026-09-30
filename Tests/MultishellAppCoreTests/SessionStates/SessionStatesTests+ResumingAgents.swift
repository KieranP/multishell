import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  private func reportResuming(
    _ states: inout SessionStates, _ state: SessionState, _ subagent: SubagentReport? = nil,
    shells: [Int32] = [], out: [String]? = nil, startsTurn: Bool = false,
    conversation: String? = nil
  ) -> SessionState? {
    states.report(
      .init(
        state: state, subagent: subagent, startsTurn: startsTurn, backgroundShells: shells,
        resumesAfterWorkers: state == .done, conversationID: conversation,
        workersOut: out.map { $0.map { SubagentReport(id: $0, phase: .working) } }), pid: 99,
      for: .session(a), isSeen: false)
  }

  @Test func theWokenTurnsStopPaysTheDoneRatherThanTheLastShellOut() {
    var states = SessionStates()
    var meant = [reportResuming(&states, .done, shells: [500])]
    meant += shellGone(&states, 500)
    #expect(states[.session(a)] == .running, "the agent is about to take the result")

    meant.append(reportResuming(&states, .running))
    meant.append(reportResuming(&states, .done))
    #expect(states[.session(a)] == .done)
    #expect(meant.filter { $0 == .done }.count == 1, "announced once, at the woken turn's end")
  }

  @Test func aWokenTurnThatOnlyStopsStillPaysOnce() {
    var states = SessionStates()
    _ = reportResuming(&states, .done, shells: [500])
    #expect(shellGone(&states, 500) == [nil])
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func theLastSubagentOutLeavesTheDoneToTheTurnItsEndStarts() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    #expect(reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  /// Hooks cross the socket in any order, so the woken turn's subagent can be
  /// heard from before the main thread's own tool call.
  @Test func aWorkerOutInTheWokenTurnLeavesItsStopToPay() {
    var states = SessionStates()
    _ = reportResuming(&states, .done, shells: [500])
    _ = shellGone(&states, 500)
    #expect(
      reportResuming(&states, .running, SubagentReport(id: "w2", phase: .started)) == .running)
    #expect(reportResuming(&states, .running, SubagentReport(id: "w2", phase: .ended)) == .running)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aSubagentStartLandingAfterTheStopLeavesTheDoneToTheWokenTurn() {
    var states = SessionStates()
    #expect(reportResuming(&states, .done) == .done)
    #expect(
      reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started)) == .running)
    #expect(reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running)
    #expect(reportResuming(&states, .done) == .done)
  }

  /// A Stop that lists what is still out, as Claude's `background_tasks` does.
  private func stopListingWorkersOut(
    _ states: inout SessionStates, out: [String], shells: [Int32] = []
  ) -> SessionState? {
    states.report(
      .init(
        state: .done, backgroundShells: shells, resumesAfterWorkers: true,
        workersOut: out.map { SubagentReport(id: $0, phase: .working) }), pid: 99, for: .session(a),
      isSeen: false)
  }

  @Test func aStopListingNothingOutPaysTheDoneThoughAnEndNeverCame() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(stopListingWorkersOut(&states, out: ["w1"]) == .running)
    #expect(
      stopListingWorkersOut(&states, out: []) == .done, "w1's SubagentStop is late or never comes")
    #expect(states.subagents(.session(a)).isEmpty)

    #expect(reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func aStopListingAWorkerWhoseStartHasNotLandedHoldsTheDone() {
    var states = SessionStates()
    #expect(stopListingWorkersOut(&states, out: ["w1"]) == .running)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .working))
    #expect(
      reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started)) == .running)
    #expect(states.subagents(.session(a)).first?.occurrences == 1, "the late start is w1's own")

    #expect(reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running, "the turn w1's end wakes pays")
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  @Test func aStopKeepsOnlyTheWorkersItListsAndThoseAfterItByHook() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(stopListingWorkersOut(&states, out: ["w2"]) == .running)
    #expect(states.subagents(.session(a)).map(\.id) == ["w2"])
  }

  @Test func aStopListingNoShellDropsTheShellsAnEarlierStopLeft() {
    var states = SessionStates()
    #expect(stopListingWorkersOut(&states, out: [], shells: [500]) == .running)
    #expect(stopListingWorkersOut(&states, out: [], shells: [500]) == .running, "still listed")
    #expect(stopListingWorkersOut(&states, out: []) == .done, "gone before the poll saw it")
    #expect(states.subagents(.session(a)).isEmpty)
  }

  @Test func aShellTheStopListsIsCountedAsAShellAndGoesWhenNoLongerListed() {
    var states = SessionStates()
    let shell = SubagentReport(id: "b1", phase: .working, isBackgroundShell: true)
    #expect(
      states.report(
        .init(state: .done, resumesAfterWorkers: true, workersOut: [shell]), pid: 99,
        for: .session(a), isSeen: false) == .running)
    #expect(states.subagents(.session(a)).countText == "1 background shell")
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  @Test func aStopTakesBackThePromptOfAWorkerItNoLongerLists() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(
      reportResuming(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)
    #expect(stopListingWorkersOut(&states, out: []) == .done)
  }

  private func cancelled(_ id: String) -> SubagentReport {
    SubagentReport(id: id, phase: .ended, wakesAgent: false)
  }

  @Test func aCancelledLastWorkerWakesNoTurnSoItsEndPaysTheDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    #expect(reportResuming(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aCancelledLastWorkerLeavesTheDoneToATurnAnEarlierEndWoke() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended))
    #expect(
      reportResuming(&states, .running, cancelled("w2")) == nil, "w1's end is about to wake it")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aCancelledLastWorkerAfterTheWokenTurnStoppedPaysTheDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, SubagentReport(id: "w2", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended))
    _ = reportResuming(&states, .running)
    #expect(reportResuming(&states, .done) == .running, "w2 is still out")
    #expect(reportResuming(&states, .running, cancelled("w2")) == .done)
  }

  @Test func aCancelledLastWorkerDuringTheWokenTurnLeavesTheDoneToThatTurnsStop() {
    var states = SessionStates()
    var meant: [SessionState?] = []
    meant.append(reportResuming(&states, .running, SubagentReport(id: "c1", phase: .started)))
    meant.append(reportResuming(&states, .running, SubagentReport(id: "c2", phase: .started)))
    meant.append(reportResuming(&states, .done, out: ["c1", "c2"]))
    meant.append(reportResuming(&states, .running, SubagentReport(id: "c1", phase: .ended)))
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
    #expect(states.subagents(.session(a)).map(\.id) == ["C"])
    #expect(reportResuming(&states, .done, conversation: "P") == .running, "C is still out")
  }

  @Test func aWorkerHeardOnlyInATurnThatNeverStoppedGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).isEmpty, "an interrupt killed it and said nothing")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aStopWithANoticeStillQueuedLeavesTheDoneToTheTurnItStarts() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended))
    let held = states.report(
      .init(state: .done, resumesAfterWorkers: true, workersOut: [], turnFollows: true), pid: 99,
      for: .session(a), isSeen: false)
    #expect(held == .running, "w1's notice starts a turn straight after")
    #expect(reportResuming(&states, .running) == .running)
    #expect(reportResuming(&states, .done, out: []) == .done)
  }

  @Test func aStopWithNothingQueuedAndNothingOutIsDone() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .ended))
    #expect(reportResuming(&states, .done, out: []) == .done)
  }

  @Test func aWorkerSilentSinceTheLastStopGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(reportResuming(&states, .done) == .running)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(reportResuming(&states, .done) == .running, "kept once: a Stop saw it out")
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).isEmpty, "silent through a whole turn, its end lost")
    #expect(reportResuming(&states, .done) == .done)
  }

  @Test func aWorkerHeardFromInTheTurnStaysOutAcrossTheNextPrompt() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .working))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aStrayEndForAWorkerNotOutWakesNoTurn() {
    var states = SessionStates()
    #expect(reportResuming(&states, .done, out: ["b"]) == .running)
    _ = reportResuming(&states, .running, SubagentReport(id: "a", phase: .ended))
    #expect(reportResuming(&states, .running, cancelled("b")) == .done, "nothing was woken for b")
  }

  @Test func aStopOverAFailureStillMarksItsWorkersOut() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .failed)
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aListedSubagentTakesItsKindFromItsStart() {
    var states = SessionStates()
    _ = states.report(
      .init(
        state: .done, resumesAfterWorkers: true,
        workersOut: [SubagentReport(id: "w1", type: "subagent", phase: .working)]), pid: 99,
      for: .session(a), isSeen: false)
    _ = reportResuming(
      &states, .running, SubagentReport(id: "w1", type: "Explore", phase: .started))
    #expect(states.subagents(.session(a)).first?.type == "Explore")
  }

  @Test func theAgentsOwnPromptWhileAStopIsHeldIsNoTurnUnderway() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .attention)
    #expect(reportResuming(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aStopListingEveryOneOfManyWorkersKeepsThemAll() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = reportResuming(&states, .running, SubagentReport(id: id, phase: .started)) }
    let listed = SessionStateReport(
      state: .done, resumesAfterWorkers: true,
      workersOut: ids.map { SubagentReport(id: $0, phase: .working) })
    _ = states.report(listed, pid: 99, for: .session(a), isSeen: false)
    for id in ids.prefix(69) {
      _ = reportResuming(&states, .running, SubagentReport(id: id, phase: .ended))
    }
    #expect(!states.subagents(.session(a)).isEmpty, "w70 is still out")
  }

  @Test func aListCutAtItsLimitTakesNobodyOff() {
    var states = SessionStates()
    _ = reportResuming(&states, .running, SubagentReport(id: "w0", phase: .started))
    let full = (1...SessionStateReport.maximumWorkersOut).map {
      SubagentReport(id: "l\($0)", phase: .working)
    }
    _ = states.report(
      .init(state: .done, resumesAfterWorkers: true, workersOut: full), pid: 99, for: .session(a),
      isSeen: false)
    #expect(states.subagents(.session(a)).contains { $0.id == "w0" }, "the cut may have held it")
  }

  @Test func aPromptKeepsTheWorkersFoldedPastTheLimitThatAStopSawOut() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = reportResuming(&states, .running, SubagentReport(id: id, phase: .started)) }
    _ = reportResuming(&states, .done)
    _ = reportResuming(&states, .running, startsTurn: true)
    for id in ids.prefix(69) {
      _ = reportResuming(&states, .running, SubagentReport(id: id, phase: .ended))
    }
    #expect(reportResuming(&states, .done) == .running, "w70 is still out")
  }

  @Test func aShellEveryStopFindsAliveStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    for _ in 0..<3 {
      _ = states.report(
        .init(state: .done, backgroundShells: [500]), pid: 99, for: .session(a), isSeen: false)
      _ = reportResuming(&states, .running, startsTurn: true)
      #expect(states.subagents(.session(a)).map(\.pid) == [500], "the Stop found it running")
    }
  }

  @Test func aShellEveryListNamesStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    let shell = SubagentReport(id: "b1", phase: .working, isBackgroundShell: true)
    for _ in 0..<3 {
      _ = states.report(
        .init(state: .done, resumesAfterWorkers: true, workersOut: [shell]), pid: 99,
        for: .session(a), isSeen: false)
      _ = reportResuming(&states, .running, startsTurn: true)
      #expect(states.subagents(.session(a)).map(\.id) == ["b1"])
    }
  }

  @Test func anAgentThatDoesNotResumeIsPaidByTheLastWorkerOut() {
    var states = SessionStates()
    states.report(
      .init(state: .done, backgroundShells: [500]), pid: 99, for: .session(a), isSeen: false)
    #expect(shellGone(&states, 500) == [.done])
  }
}
