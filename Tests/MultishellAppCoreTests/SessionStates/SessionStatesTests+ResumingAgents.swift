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

  /// A Stop that lists what is still out, as Claude's `background_tasks` does.
  private func stop(
    _ states: inout SessionStates, out: [String], shells: [Int32] = []
  ) -> SessionState? {
    states.report(
      .done, pid: 99, backgroundShells: shells, resumesAfterWorkers: true,
      workersOut: out.map { SubagentReport(id: $0, phase: .working) }, for: .session(a),
      isSeen: false)
  }

  @Test func aStopListingNothingOutPaysTheDoneThoughAnEndNeverCame() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(stop(&states, out: ["w1"]) == .running)
    #expect(stop(&states, out: []) == .done, "w1's SubagentStop is late or never comes")
    #expect(states.subagents(.session(a)).isEmpty)

    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func aStopListingAWorkerWhoseStartHasNotLandedHoldsTheDone() {
    var states = SessionStates()
    #expect(stop(&states, out: ["w1"]) == .running)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .working))
    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .started)) == .running)
    #expect(states.subagents(.session(a)).first?.occurrences == 1, "the late start is w1's own")

    #expect(report(&states, .running, SubagentReport(id: "w1", phase: .ended)) == nil)
    #expect(states[.session(a)] == .running, "the turn w1's end wakes pays")
    #expect(stop(&states, out: []) == .done)
  }

  @Test func aStopKeepsOnlyTheWorkersItListsAndThoseAfterItByHook() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(stop(&states, out: ["w2"]) == .running)
    #expect(states.subagents(.session(a)).map(\.id) == ["w2"])
  }

  @Test func aStopListingNoShellDropsTheShellsAnEarlierStopLeft() {
    var states = SessionStates()
    #expect(stop(&states, out: [], shells: [500]) == .running)
    #expect(stop(&states, out: [], shells: [500]) == .running, "still listed")
    #expect(stop(&states, out: []) == .done, "gone before the poll saw it")
    #expect(states.subagents(.session(a)).isEmpty)
  }

  @Test func aShellTheStopListsIsCountedAsAShellAndGoesWhenNoLongerListed() {
    var states = SessionStates()
    let shell = SubagentReport(id: "b1", phase: .working, isShell: true)
    #expect(
      states.report(
        .done, pid: 99, resumesAfterWorkers: true, workersOut: [shell], for: .session(a),
        isSeen: false) == .running)
    #expect(states.subagents(.session(a)).countText == "1 background shell")
    #expect(stop(&states, out: []) == .done)
  }

  @Test func aStopTakesBackThePromptOfAWorkerItNoLongerLists() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)
    #expect(stop(&states, out: []) == .done)
  }

  private func cancelled(_ id: String) -> SubagentReport {
    SubagentReport(id: id, phase: .ended, wakesAgent: false)
  }

  @Test func aCancelledLastWorkerWakesNoTurnSoItsEndPaysTheDone() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(report(&states, .done) == .running)
    #expect(report(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aCancelledLastWorkerLeavesTheDoneToATurnAnEarlierEndWoke() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w2", phase: .started))
    #expect(report(&states, .done) == .running)
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .ended))
    #expect(report(&states, .running, cancelled("w2")) == nil, "w1's end is about to wake it")
    #expect(report(&states, .done) == .done)
  }

  @Test func aCancelledLastWorkerAfterTheWokenTurnStoppedPaysTheDone() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w2", phase: .started))
    _ = report(&states, .done)
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .ended))
    _ = report(&states, .running)
    #expect(report(&states, .done) == .running, "w2 is still out")
    #expect(report(&states, .running, cancelled("w2")) == .done)
  }

  private func probe(
    _ states: inout SessionStates, _ state: SessionState, _ subagent: SubagentReport? = nil,
    out: [String]? = nil, startsTurn: Bool = false, conversation: String? = nil
  ) -> SessionState? {
    states.report(
      state, pid: 99, subagent: subagent, startsTurn: startsTurn,
      resumesAfterWorkers: state == .done,
      workersOut: out.map { $0.map { SubagentReport(id: $0, phase: .working) } },
      conversationID: conversation, for: .session(a), isSeen: false)
  }

  @Test func aCancelledLastWorkerDuringTheWokenTurnLeavesTheDoneToThatTurnsStop() {
    var states = SessionStates()
    var meant: [SessionState?] = []
    meant.append(probe(&states, .running, SubagentReport(id: "c1", phase: .started)))
    meant.append(probe(&states, .running, SubagentReport(id: "c2", phase: .started)))
    meant.append(probe(&states, .done, out: ["c1", "c2"]))
    meant.append(probe(&states, .running, SubagentReport(id: "c1", phase: .ended)))
    meant.append(probe(&states, .running))
    meant.append(probe(&states, .running, cancelled("c2")))
    #expect(states[.session(a)] == .running, "the woken turn is still running")
    meant.append(probe(&states, .done, out: []))
    #expect(meant.filter { $0 == .done }.count == 1)
  }

  @Test func aWorkerOutAtTheStopStaysOutAcrossTheNextPrompt() {
    var states = SessionStates()
    _ = probe(&states, .running, startsTurn: true, conversation: "P")
    _ = probe(&states, .running, conversation: "C")
    #expect(probe(&states, .done, conversation: "P") == .running)
    _ = probe(&states, .running, startsTurn: true, conversation: "P")
    #expect(states.subagents(.session(a)).map(\.id) == ["C"])
    #expect(probe(&states, .done, conversation: "P") == .running, "C is still out")
  }

  @Test func aWorkerHeardOnlyInATurnThatNeverStoppedGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = probe(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).isEmpty, "an interrupt killed it and said nothing")
    #expect(probe(&states, .done) == .done)
  }

  @Test func aStopWithANoticeStillQueuedLeavesTheDoneToTheTurnItStarts() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .ended))
    let held = states.report(
      .done, pid: 99, resumesAfterWorkers: true, workersOut: [], turnFollows: true,
      for: .session(a), isSeen: false)
    #expect(held == .running, "w1's notice starts a turn straight after")
    #expect(probe(&states, .running) == .running)
    #expect(probe(&states, .done, out: []) == .done)
  }

  @Test func aStopWithNothingQueuedAndNothingOutIsDone() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .ended))
    #expect(probe(&states, .done, out: []) == .done)
  }

  @Test func aWorkerSilentSinceTheLastStopGoesAtTheNextPrompt() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    #expect(probe(&states, .done) == .running)
    _ = probe(&states, .running, startsTurn: true)
    #expect(probe(&states, .done) == .running, "kept once: a Stop saw it out")
    _ = probe(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).isEmpty, "silent through a whole turn, its end lost")
    #expect(probe(&states, .done) == .done)
  }

  @Test func aWorkerHeardFromInTheTurnStaysOutAcrossTheNextPrompt() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = probe(&states, .done)
    _ = probe(&states, .running, startsTurn: true)
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .working))
    _ = probe(&states, .done)
    _ = probe(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aStrayEndForAWorkerNotOutWakesNoTurn() {
    var states = SessionStates()
    #expect(probe(&states, .done, out: ["b"]) == .running)
    _ = report(&states, .running, SubagentReport(id: "a", phase: .ended))
    #expect(probe(&states, .running, cancelled("b")) == .done, "nothing was woken for b")
  }

  @Test func aStopOverAFailureStillMarksItsWorkersOut() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = probe(&states, .failed)
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = probe(&states, .done)
    _ = probe(&states, .running, startsTurn: true)
    #expect(states.subagents(.session(a)).map(\.id) == ["w1"])
  }

  @Test func aListedSubagentTakesItsKindFromItsStart() {
    var states = SessionStates()
    _ = states.report(
      .done, pid: 99, resumesAfterWorkers: true,
      workersOut: [SubagentReport(id: "w1", type: "subagent", phase: .working)],
      for: .session(a), isSeen: false)
    _ = report(&states, .running, SubagentReport(id: "w1", type: "Explore", phase: .started))
    #expect(states.subagents(.session(a)).first?.type == "Explore")
  }

  @Test func theAgentsOwnPromptWhileAStopIsHeldIsNoTurnUnderway() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w1", phase: .started))
    _ = probe(&states, .done)
    _ = probe(&states, .attention)
    #expect(probe(&states, .running, cancelled("w1")) == .done)
  }

  @Test func aStopListingEveryOneOfManyWorkersKeepsThemAll() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = report(&states, .running, SubagentReport(id: id, phase: .started)) }
    let listed = SessionStateReport(
      state: .done, workersOut: ids.map { SubagentReport(id: $0, phase: .working) })
    _ = states.report(
      .done, pid: 99, resumesAfterWorkers: true, workersOut: listed.workersOut,
      for: .session(a), isSeen: false)
    for id in ids.prefix(69) {
      _ = report(&states, .running, SubagentReport(id: id, phase: .ended))
    }
    #expect(!states.subagents(.session(a)).isEmpty, "w70 is still out")
  }

  @Test func aListCutAtItsLimitTakesNobodyOff() {
    var states = SessionStates()
    _ = report(&states, .running, SubagentReport(id: "w0", phase: .started))
    let full = (1...SessionStateReport.maximumListedWorkers).map {
      SubagentReport(id: "l\($0)", phase: .working)
    }
    _ = states.report(
      .done, pid: 99, resumesAfterWorkers: true, workersOut: full, for: .session(a), isSeen: false)
    #expect(states.subagents(.session(a)).contains { $0.id == "w0" }, "the cut may have held it")
  }

  @Test func aPromptKeepsTheWorkersFoldedPastTheLimitThatAStopSawOut() {
    var states = SessionStates()
    let ids = (1...70).map { "w\($0)" }
    for id in ids { _ = report(&states, .running, SubagentReport(id: id, phase: .started)) }
    _ = probe(&states, .done)
    _ = probe(&states, .running, startsTurn: true)
    for id in ids.prefix(69) {
      _ = report(&states, .running, SubagentReport(id: id, phase: .ended))
    }
    #expect(probe(&states, .done) == .running, "w70 is still out")
  }

  @Test func aShellEveryStopFindsAliveStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    for _ in 0..<3 {
      _ = states.report(.done, pid: 99, backgroundShells: [500], for: .session(a), isSeen: false)
      _ = probe(&states, .running, startsTurn: true)
      #expect(states.subagents(.session(a)).map(\.pid) == [500], "the Stop found it running")
    }
  }

  @Test func aShellEveryListNamesStaysOutAcrossEachPrompt() {
    var states = SessionStates()
    let shell = SubagentReport(id: "b1", phase: .working, isShell: true)
    for _ in 0..<3 {
      _ = states.report(
        .done, pid: 99, resumesAfterWorkers: true, workersOut: [shell], for: .session(a),
        isSeen: false)
      _ = probe(&states, .running, startsTurn: true)
      #expect(states.subagents(.session(a)).map(\.id) == ["b1"])
    }
  }

  @Test func anAgentThatDoesNotResumeIsPaidByTheLastWorkerOut() {
    var states = SessionStates()
    states.report(.done, pid: 99, backgroundShells: [500], for: .session(a), isSeen: false)
    #expect(shellGone(&states, 500) == [.done])
  }
}
