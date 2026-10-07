import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Claude Code's `Stop` ends its main loop while background subagents still work; their
/// own end is a separate event. See Docs/design/agents.md.
extension SessionStatesTests {
  @Test func doneWaitsForTheLastWorkerOutRatherThanTheMainLoopStopping() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w2"))

    #expect(report(&states, .done) == .running, "two are still working")
    #expect(states[.session(a)] == .running)

    #expect(report(&states, .running, ended("w1")) == .running, "one to go")
    #expect(report(&states, .running, ended("w2")) == .done, "the last one out pays it")
    #expect(states[.session(a)] == .done)
    #expect(workersOut(states).isEmpty)
  }

  /// The banner rides on what the report was taken to mean, so it fires once,
  /// at the end, rather than once per wave of workers.
  @Test func aTurnWithWorkersMeansDoneExactlyOnce() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    let atStop = report(&states, .done)
    let atLastWorker = report(&states, .running, ended("w1"))

    #expect(atStop == .running, "the main loop stopping is not the banner's moment")
    #expect(atLastWorker == .done, "the last worker out is")
    #expect([atStop, atLastWorker].filter { $0 == .done }.count == 1)
  }

  @Test func anAgentThatReportsNoWorkersIsUnaffected() {
    var states = SessionStates()
    #expect(report(&states, .running) == .running)
    #expect(report(&states, .done) == .done, "no roster, so Done is Done as it always was")
    #expect(states[.session(a)] == .done)
  }

  @Test func aSessionEndingOrFailingSettlesTheTurnWhateverIsStillOut() {
    for ending in [SessionState.idle, .failed] {
      var states = SessionStates()
      _ = report(&states, .running, started("w1"))
      _ = report(&states, .done)
      #expect(report(&states, ending) == ending)
      #expect(workersOut(states).isEmpty, "\(ending): nothing is out")
      #expect(report(&states, .running, ended("w1")) == nil, "\(ending)")
      #expect(states[.session(a)] == (ending == .failed ? .failed : nil), "\(ending)")
    }
  }

  @Test func aStopWithNoWorkerOutIsStillDoneAfterAWorkerHasComeAndGone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, ended("w1"))
    #expect(report(&states, .done) == .done)
  }

  /// A Stop that names a worker, which no agent documents, is the agent's
  /// Stop: it puts no phantom on the roster to hold the Done for.
  @Test func anAgentsOwnStateNamingAWorkerAddsNoneToTheRoster() {
    var states = SessionStates()
    _ = report(&states, .running)
    #expect(report(&states, .done, working("w1")) == .done)
    #expect(workersOut(states).isEmpty)
  }

  /// A worker ending with none out cannot put the roster in debt, or the
  /// next turn's Done would be owed forever; nor is it work on an idle pane.
  @Test func aStrayWorkerEndingLeavesNothingOwedAndMovesNothing() {
    var states = SessionStates()
    #expect(report(&states, .running, ended("w1")) == nil)
    #expect(states.showsNothing)
    #expect(report(&states, .done) == .done)
  }

  @Test func theRosterIsKeptByIdInOrderOfArrival() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, working("w2"))
    _ = report(&states, .running, started("w3", type: "Plan"))
    #expect(workersOut(states) == ["w1", "w2", "w3"])
    #expect(states.workers(.session(a)).map(\.type) == ["Explore", "Explore", "Plan"])

    _ = report(&states, .running, ended("w2"))
    #expect(workersOut(states) == ["w1", "w3"])
    _ = report(&states, .running, ended("nobody"))
    #expect(workersOut(states) == ["w1", "w3"], "an end for a worker never seen takes nothing")
  }

  /// Copilot names a worker and gives no id, so two of one kind share a roster
  /// place. The second start counts, so the first stop pays no Done.
  @Test func twoWorkersUnderOneNameTakeTwoEndsToPayADone() {
    var states = SessionStates()
    _ = report(&states, .running)
    report(&states, .init(state: .done))

    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("code-review"))
    #expect(workersOut(states) == ["code-review"], "one place on the roster")
    _ = report(&states, .running, working("code-review"))

    #expect(report(&states, .running, ended("code-review")) == .running, "one is still out")
    #expect(workersOut(states) == ["code-review"])
    #expect(report(&states, .running, ended("code-review")) == .done)
    #expect(workersOut(states).isEmpty)
  }

  /// Two workers under one name are two workers: the chip says two where the
  /// roster holds one place for them, or a pane reads as half as busy as it is.
  @Test func theChipCountsWorkersAndNotRosterPlaces() {
    var states = SessionStates()
    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("w1"))
    let workers = states.workers(.session(a))
    #expect(workers.count == 2, "two places")
    #expect(workers.workerCount == 3, "three workers")
    #expect(workers.first?.occurrenceText == t("worker.occurrences", 2))
    #expect(workers.last?.occurrenceText == nil, "a place of one says nothing")

    _ = report(&states, .running, ended("code-review"))
    #expect(states.workers(.session(a)).workerCount == 2)
  }

  /// A stop naming no worker still lets one go; read as the agent's own report, the place
  /// would stand all turn and the Done its Stop owed would never be paid.
  @Test func anEndThatNamesNoWorkerTakesOneOffTheRoster() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    #expect(states[.session(a)] == .running, "the Done is held while one is out")

    let unnamed = WorkerReport(id: WorkerReport.anonymousID, phase: .ended)
    #expect(report(&states, .running, unnamed) == .done, "the last one out pays it")
    #expect(workersOut(states).isEmpty)
  }

  /// So the sidebar and a list open over it are not re-rendered per call.
  @Test func aWorkersToolCallsLeaveTheRosterAsItWas() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    let before = states
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(states == before)
  }

  /// A worker's start time is stamped as a state's is, by the model's one
  /// clock, and a later report about it does not reset it.
  @Test func aWorkerIsStampedOnceAtItsFirstReport() {
    var states = SessionStates()
    let before = SessionStates()
    _ = report(&states, .running, started("w1"))
    let first = Date(timeIntervalSince1970: 1000)
    states.stampChanges(against: before, at: first)
    #expect(states.workers(.session(a)).first?.since == first)

    let stamped = states
    _ = report(&states, .running, working("w1"))
    states.stampChanges(against: stamped, at: first.addingTimeInterval(30))
    #expect(states.workers(.session(a)).first?.since == first, "it moved, its start did not")
  }

  /// A helper from before workers had names writes a count: each `1` is a worker
  /// of its own and each `-1` takes the last of them.
  @Test func anOlderHelpersCountIsKeptAsUnnamedWorkers() {
    var states = SessionStates()
    let anonymous = WorkerReport.anonymousID
    _ = report(&states, .running, WorkerReport(id: anonymous, phase: .started))
    _ = report(&states, .running, WorkerReport(id: anonymous, phase: .started))
    _ = report(&states, .running, started("w1"))
    #expect(states.workers(.session(a)).count == 3)
    #expect(states.workers(.session(a)).map(\.type) == [nil, nil, "Explore"])

    _ = report(&states, .running, ended(anonymous))
    #expect(states.workers(.session(a)).map(\.type) == [nil, "Explore"])
    _ = report(&states, .done)
    _ = report(&states, .running, ended("w1"))
    #expect(states[.session(a)] == .running, "an unnamed one is still out")
    #expect(report(&states, .running, ended(anonymous)) == .done)
  }

  @Test func aWorkerOutLiftsADoneToWorkingAndTheLastOutPaysItBack() {
    var states = SessionStates()
    _ = report(&states, .running)
    report(&states, .init(state: .done, message: "all green"))

    #expect(report(&states, .running, started("w1")) == .running)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(report(&states, .running, ended("w1")) == .done, "the Done it displaced comes back")
    #expect(states[.session(a)] == .done)
  }

  /// No Done was displaced, so none is owed.
  @Test func aWorkerOutLiftsNothingToWorkingAndTheLastOutClearsIt() {
    var states = SessionStates()
    #expect(report(&states, .running, started("w1")) == .running)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, ended("w1")) == .idle)
    #expect(states[.session(a)] == nil)
    #expect(states.showsNothing, "nothing left behind")
  }

  @Test func anAgentsOwnWorkingOutlivesTheWorkerThatLiftedIt() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    #expect(report(&states, .running) == .running)
    #expect(report(&states, .running, ended("w1")) == .running)
    #expect(states[.session(a)] == .running, "the agent said so itself")
    #expect(report(&states, .done) == .done)
  }

  @Test func aWorkerFirstSeenAtAToolCallLiftsAsAStartDoes() {
    var overDone = SessionStates()
    _ = report(&overDone, .running)
    _ = report(&overDone, .done)
    #expect(report(&overDone, .running, working("w1")) == .running)
    #expect(report(&overDone, .running, ended("w1")) == .done)

    var overNothing = SessionStates()
    #expect(report(&overNothing, .running, working("w1")) == .running)
    #expect(report(&overNothing, .running, ended("w1")) == .idle)
    #expect(overNothing.showsNothing)
  }

  /// The agent died with a worker out, so no SubagentStop or SessionEnd
  /// arrives to settle it; the shell's own end of that command has to.
  @Test func theShellsCommandEndingSettlesWorkersItsDeadAgentLeftOut() {
    var engineFirst = SessionStates()
    _ = report(&engineFirst, .running, started("w1"))
    engineFirst.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(workersOut(engineFirst).isEmpty)
    #expect(report(&engineFirst, .done) == .done, "the shell's own done is not held for a worker")
    #expect(engineFirst[.session(a)] == .done)

    var socketFirst = SessionStates()
    _ = report(&socketFirst, .running, started("w1"))
    _ = report(&socketFirst, .done)
    socketFirst.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    _ = report(&socketFirst, .running)
    #expect(report(&socketFirst, .done) == .done, "the next session owes nothing from the last")
  }

  @Test func anAgentWhoseProcessIsGoneOwesNothing() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    states.noteProcessGone(99)
    #expect(workersOut(states).isEmpty)
    #expect(report(&states, .done) == .done, "the held Done went with the process")
  }

  /// An agent fires no hook on Ctrl+C and the workers it killed send no stop, so
  /// the next prompt drops a worker no Stop saw out.
  @Test func aNewTurnClearsWhatTheLastTurnOwedButKeepsWhatItsStopSawOut() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    #expect(states[.session(a)] == .running, "held for the worker")

    #expect(
      report(&states, .init(state: .running, startsTurn: true))
        == .running)
    #expect(workersOut(states) == ["w1"], "a background worker outlives the turn")
    #expect(report(&states, .done) == .running, "and holds the next Stop")
    #expect(report(&states, .running, ended("w1")) == .done, "until it ends")

    var lifted = SessionStates()
    _ = report(&lifted, .running, started("w1"))
    _ = lifted.apply(
      .init(state: .running, startsTurn: true), pid: 99, for: .session(a), isSeen: false)
    #expect(lifted[.session(a)] == .running, "the agent's own Working now")
    #expect(report(&lifted, .running, ended("w1")) == .running, "a late end takes nothing back")
  }

  /// Hooks are separate processes over a socket, so a main-thread event can
  /// land after the Stop it preceded. The Done owed to the workers survives it.
  @Test func aHeldDoneOutlivesTheAgentsOwnLaterWorking() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    #expect(report(&states, .done) == .running, "held for the worker")
    #expect(report(&states, .running) == .running, "a main-thread hook overtaking the Stop")
    #expect(report(&states, .running, ended("w1")) == .done, "the Done is still owed")
    #expect(states[.session(a)] == .done)
  }

  /// A fresh place per call would grow the roster all turn.
  @Test func anUnnamedWorkersToolCallTakesAPlaceAlreadyOut() {
    var states = SessionStates()
    let call = WorkerReport(id: WorkerReport.anonymousID, phase: .working)
    _ = report(&states, .running, call)
    _ = report(&states, .running, call)
    #expect(workersOut(states).count == 1)
  }

  @Test func theUsersClearTakesTheRoster() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    states.clear(.session(a))
    #expect(workersOut(states).isEmpty)
    #expect(states.showsNothing)
  }
}
