import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Who clears what, on the plain value the model and the views read.
@Suite
struct SessionStatesTests {
  private let a = UUID()
  private let b = UUID()

  @Test func doneIsAboutTheUserAndClearsWhenSeen() {
    var states = SessionStates()
    states.report(.done, pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == .done)
    states.markSeen(sessions: [a], worktree: nil)
    #expect(states[.session(a)] == nil)

    states.report(.done, pid: nil, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == nil, "a report about a tab being looked at is seen already")
  }

  @Test func workingAndWaitingStayWhileTheUserLooks() {
    var states = SessionStates()
    states.report(.running, pid: 10, for: .session(a), isSeen: true)
    states.report(.attention, pid: 11, for: .session(b), isSeen: true)
    states.markSeen(sessions: [a, b], worktree: nil)
    #expect(states[.session(a)] == .running)
    #expect(states[.session(b)] == .attention)
    #expect(states.trackedPIDs == [10, 11])
  }

  /// A failure asks to be dealt with, so a look does not clear it, and
  /// neither does the death of the process that failed: it borrows Waiting's
  /// rule about being seen and Done's about a gone process. What clears it is
  /// the source saying something else, or the user's own clear.
  @Test func failedSurvivesALookAndTheProcessThatFailed() {
    var states = SessionStates()
    states.report(.error, pid: 7, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == .error, "reported about a pane being looked at, and it stays")
    states.markSeen(sessions: [a], worktree: nil)
    #expect(states[.session(a)] == .error)
    states.processGone(7)
    #expect(states[.session(a)] == .error, "the failure outlives what failed")

    states.report(.running, pid: 8, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == .running, "the source reporting again clears it")

    states.report(.error, pid: 9, for: .session(b), isSeen: false)
    states.clear(.session(b))
    #expect(states[.session(b)] == nil, "and so does the user's own clear")
  }

  @Test func theSourceClearsWaitingByReportingAgain() {
    var states = SessionStates()
    states.report(.attention, pid: 7, for: .session(a), isSeen: false)
    states.report(.running, pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == .running)
    #expect(states.pids[.session(a)] == 7, "the pid survives a report without one")
    states.report(.idle, pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == nil)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func engineActivityNeverDowngradesAReportedState() {
    var states = SessionStates()
    states.report(.running, pid: nil, for: .session(a), isSeen: false)
    states.noteActivity(in: a, isSeen: false)
    #expect(states[.session(a)] == .running, "an agent retitles the tab on every step")

    states.noteActivity(in: b, isSeen: false)
    #expect(states[.session(b)] == .done, "a plain shell's bell is the old dot")
    states.noteActivity(in: UUID(), isSeen: true)
    #expect(states.states.count == 2)
  }

  @Test func aFinishedCommandOutranksAReport() {
    var states = SessionStates()
    states.report(.running, pid: 5, for: .session(a), isSeen: false)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(states[.session(a)] == .done, "the agent exited, and the user has not seen that")
    #expect(states.trackedPIDs.isEmpty)

    states.report(.attention, pid: 6, for: .session(b), isSeen: true)
    states.noteCommandFinished(in: b, exitCode: 0, isSeen: true)
    #expect(states[.session(b)] == nil)
  }

  @Test func aNonZeroExitIsFailedAndOutlivesAnUnseenDone() {
    var states = SessionStates()
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    states.noteCommandFinished(in: a, exitCode: 2, isSeen: false)
    #expect(states[.session(a)] == .error)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(states[.session(a)] == .error, "a later success does not hide the failure")
    states.noteCommandFinished(in: a, exitCode: 130, isSeen: false)
    #expect(states[.session(a)] == .error)

    states.noteCommandFinished(in: b, exitCode: 130, isSeen: false)
    #expect(states[.session(b)] == .done, "Ctrl+C is not a failure")
    states.report(.error, pid: nil, for: .worktree("/w"), isSeen: false)
    #expect(states[.worktree("/w")] == .error)
    states.markSeen(sessions: [a], worktree: "/w")
    #expect(
      states[.session(a)] == .error && states[.worktree("/w")] == .error,
      "a look is not dealing with a failure")
    states.clear(sessions: [a], worktree: "/w")
    #expect(states[.session(a)] == nil && states[.worktree("/w")] == nil, "clearing by hand is")
  }

  @Test func aGoneProcessTakesWorkingAndWaitingButNotDone() {
    var states = SessionStates()
    states.report(.running, pid: 42, for: .session(a), isSeen: false)
    states.report(.attention, pid: 42, for: .worktree("/w"), isSeen: false)
    states.report(.done, pid: nil, for: .session(b), isSeen: false)

    states.processGone(42)

    #expect(states[.session(a)] == nil)
    #expect(states[.worktree("/w")] == nil)
    #expect(states[.session(b)] == .done)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func theMostUrgentOfATabOrWorktreeWins() {
    var states = SessionStates()
    states.report(.done, pid: nil, for: .session(a), isSeen: false)
    states.report(.running, pid: nil, for: .session(b), isSeen: false)
    #expect(states.state(ofSessions: [a, b]) == .running)
    states.report(.attention, pid: nil, for: .worktree("/w"), isSeen: false)
    #expect(states.state(ofWorktree: "/w", sessions: [a, b]) == .attention)
    #expect(states.state(ofWorktree: "/other", sessions: []) == nil)
    #expect(states.workingSessionCount == 1, "worktree-level Working is nobody's shell")
  }

  @Test func retainDropsWhatNoLongerExists() {
    var states = SessionStates()
    states.report(.running, pid: 1, for: .session(a), isSeen: false)
    states.report(.running, pid: 2, for: .session(b), isSeen: false)
    states.report(.done, pid: nil, for: .worktree("/w"), isSeen: false)
    states.retain(sessions: [a], worktrees: [])
    #expect(states.states.keys.contains(.session(a)))
    #expect(states.states.count == 1)
    #expect(states.trackedPIDs == [1])
  }

  @Test func aStateThatMovesIsStampedAndOneThatRepeatsIsNot() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var states = SessionStates()

    var stamped = states
    stamped.report(.running, pid: 1, for: .session(a), isSeen: false)
    stamped.stampChanges(against: states, at: start)
    #expect(stamped.since[.session(a)] == start)

    // An agent reports Working on every tool call; how long it has been
    // working must not keep resetting.
    states = stamped
    var again = states
    again.report(.running, pid: 1, for: .session(a), isSeen: false)
    again.stampChanges(against: states, at: start.addingTimeInterval(60))
    #expect(again.since[.session(a)] == start, "the state did not move")

    states = again
    var finished = states
    finished.report(.done, pid: nil, for: .session(a), isSeen: false)
    finished.stampChanges(against: states, at: start.addingTimeInterval(90))
    #expect(finished.since[.session(a)] == start.addingTimeInterval(90))
  }

  /// Idle is never a stored state, so the board reads how long a pane has
  /// been idle from the stamp its last state left behind.
  @Test func goingBackToNothingIsStampedTooAndDropsTheNote() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var states = SessionStates()
    states.report(.attention, pid: 1, message: "Needs Bash", for: .session(a), isSeen: false)
    #expect(states.notes[.session(a)]?.message == "Needs Bash")

    var cleared = states
    cleared.markSeen(sessions: [a], worktree: nil)
    cleared.report(.idle, pid: nil, for: .session(a), isSeen: false)
    cleared.stampChanges(against: states, at: start)
    #expect(cleared[.session(a)] == nil)
    #expect(cleared.since[.session(a)] == start)
    #expect(cleared.notes[.session(a)] == nil, "nothing left for the note to be about")
  }

  @Test func aNoteCarriesTheStateItArrivedWith() {
    var states = SessionStates()
    states.report(.done, pid: nil, duration: 194, for: .session(a), isSeen: false)
    let note = states.notes[.session(a)]
    #expect(note?.state == .done)
    #expect(note?.duration == 194)
    #expect(note?.describing(.done) == note)
    #expect(note?.describing(.attention) == nil, "it stopped describing the pane")
  }

  @Test func aReportAboutAShownTabLeavesNoNote() {
    var states = SessionStates()
    states.report(.done, pid: nil, duration: 3, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == nil)
    #expect(states.notes[.session(a)] == nil)
  }

  @Test func retainDropsTheStampsAndNotesWithTheirKeys() {
    var states = SessionStates()
    states.report(.running, pid: 1, message: "building", for: .session(a), isSeen: false)
    states.report(.running, pid: 2, message: "testing", for: .session(b), isSeen: false)
    states.stampChanges(against: SessionStates(), at: Date(timeIntervalSince1970: 1))
    states.retain(sessions: [a], worktrees: [])
    #expect(states.since.keys.map { $0 } == [.session(a)])
    #expect(states.notes.keys.map { $0 } == [.session(a)])
  }

  @Test func clearingByHandTakesEverythingForTheKeys() {
    var states = SessionStates()
    states.report(.running, pid: 1, for: .session(a), isSeen: false)
    states.report(.attention, pid: 2, for: .worktree("/w"), isSeen: false)
    states.clear(sessions: [a], worktree: "/w")
    #expect(states.isEmpty && states.trackedPIDs.isEmpty)
  }
}

@Suite
struct NotificationPolicyTests {
  private let everyState = NotificationPreference(attention: true, error: true, done: true)
  private let waitingOnly = NotificationPreference(attention: true)

  @Test func aTabTheUserHasSeenIsNotWorthABanner() {
    #expect(
      !NotificationPolicy.shouldNotify(.attention, preference: everyState, isSeen: true))
    #expect(
      NotificationPolicy.shouldNotify(.attention, preference: everyState, isSeen: false),
      "on screen while the user is in another app is not seen")
    #expect(NotificationPolicy.shouldNotify(.done, preference: everyState, isSeen: false))
    #expect(!NotificationPolicy.shouldNotify(.done, preference: waitingOnly, isSeen: false))
    #expect(!NotificationPolicy.shouldNotify(.running, preference: everyState, isSeen: false))
  }

  /// A permission prompt reports twice, once at the prompt and once when
  /// the agent decides nobody has answered. The dot moves on both, and the
  /// second one carries the banner for the pair.
  @Test func aSilentReportMovesTheDotAndRaisesNoBanner() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false, silent: true))
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false),
      "the same report without the flag is the banner")
  }

  @Test func aShortCommandDoesNotEarnABannerButAnAgentOrALongOneDoes() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: 0.2),
      "ls in a background tab")
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: 45))
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: everyState, isSeen: false, duration: nil),
      "an agent's Stop hook carries no duration")
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: everyState, isSeen: false, duration: 0.1),
      "waiting is never short")
  }

  @Test func theBodyPrefersTheSourcesMessage() {
    #expect(NotificationPolicy.body(for: .attention, message: "Needs Bash") == "Needs Bash")
    #expect(NotificationPolicy.body(for: .attention, message: "") == "Waiting for your input.")
    #expect(NotificationPolicy.body(for: .done, message: nil) == "Finished.")
  }
}

/// Claude Code's `Stop` is its main assistant loop stopping, which happens
/// while subagents launched in the background are still working; their own
/// end is a separate event. See Docs/design/agents.md.
@Suite
struct BackgroundWorkerTests {
  private let a = UUID()

  private func started(_ id: String, type: String? = "Explore") -> SubagentReport {
    SubagentReport(id: id, type: type, phase: .started)
  }

  private func working(_ id: String) -> SubagentReport {
    SubagentReport(id: id, type: "Explore", phase: .working)
  }

  private func ended(_ id: String) -> SubagentReport {
    SubagentReport(id: id, phase: .ended)
  }

  /// `nil` where the report was only bookkeeping.
  private func report(
    _ states: inout SessionStates, _ state: SessionState, _ subagent: SubagentReport? = nil
  ) -> SessionState? {
    states.report(state, pid: 99, subagent: subagent, for: .session(a), isSeen: false)
  }

  private func out(_ states: SessionStates) -> [String] {
    states.subagents(.session(a)).map(\.id)
  }

  @Test func doneWaitsForTheLastWorkerOutRatherThanTheMainLoopStopping() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w2"))

    #expect(report(&states, .done) == .running, "two are still working")
    #expect(states[.session(a)] == .running)

    #expect(report(&states, .running, ended("w1")) == .running, "one to go")
    #expect(report(&states, .running, ended("w2")) == .done, "the last one out pays it")
    #expect(states[.session(a)] == .done)
    #expect(out(states).isEmpty)
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
    for ending in [SessionState.idle, .error] {
      var states = SessionStates()
      _ = report(&states, .running, started("w1"))
      _ = report(&states, .done)
      #expect(report(&states, ending) == ending)
      #expect(out(states).isEmpty, "\(ending): nothing is out")
      // Nothing is owed now, so a worker ending later pays nothing and moves
      // nothing: an ended session stays idle, and a failure stands.
      #expect(report(&states, .running, ended("w1")) == nil, "\(ending)")
      #expect(states[.session(a)] == (ending == .error ? .error : nil), "\(ending)")
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
    #expect(out(states).isEmpty)
  }

  /// A worker ending with none out cannot put the roster in debt, or the
  /// next turn's Done would be owed forever; nor is it work on an idle pane.
  @Test func aStrayWorkerEndingLeavesNothingOwedAndMovesNothing() {
    var states = SessionStates()
    #expect(report(&states, .running, ended("w1")) == nil)
    #expect(states.isEmpty)
    #expect(report(&states, .done) == .done)
  }

  /// A worker that ends with its prompt still up, the user having denied it,
  /// takes the prompt with it: what it displaced comes back.
  @Test func aWorkerEndingTakesItsOwnWaitingWithIt() {
    var overWorking = SessionStates()
    _ = report(&overWorking, .running)
    _ = report(&overWorking, .running, started("w1"))
    _ = report(&overWorking, .attention, SubagentReport(id: "w1", phase: .working))
    #expect(report(&overWorking, .running, ended("w1")) == .running)
    #expect(overWorking[.session(a)] == .running)
    #expect(report(&overWorking, .running) == .running, "nothing holds the agent now")
    #expect(report(&overWorking, .done) == .done)

    var overNothing = SessionStates()
    _ = report(&overNothing, .running, started("w1"))
    _ = report(&overNothing, .attention, SubagentReport(id: "w1", phase: .working))
    #expect(report(&overNothing, .running, ended("w1")) == .idle)
    #expect(overNothing.isEmpty)
  }

  /// The main loop stopping over a worker's prompt does not answer it: the
  /// Done is owed and the prompt stays on the dot until that worker moves.
  @Test func aStopOverAWorkersWaitingHoldsThePrompt() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .attention, SubagentReport(id: "w1", phase: .working))
    #expect(report(&states, .done) == nil, "not news while the prompt is up")
    #expect(states[.session(a)] == .attention)
    #expect(report(&states, .running, working("w1")) == .running, "answered")
    #expect(report(&states, .running, ended("w1")) == .done, "and the Done paid")
  }

  /// Two prompts up at once are two questions: answering one leaves the dot
  /// on the other until it too is answered.
  @Test func eachPromptIsClearedByItsOwnThread() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w2"))
    _ = report(&states, .attention, SubagentReport(id: "w1", phase: .working))
    _ = report(&states, .attention, SubagentReport(id: "w2", phase: .working))
    #expect(report(&states, .running, working("w2")) == nil, "w1 is still asking")
    #expect(states[.session(a)] == .attention)
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(states[.session(a)] == .running)
  }

  /// The roster is by id: the same worker reported twice is one worker, and
  /// one whose start went unseen joins at its first tool call.
  @Test func theRosterIsKeptByIdInOrderOfArrival() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, working("w2"))
    _ = report(&states, .running, started("w3", type: "Plan"))
    #expect(out(states) == ["w1", "w2", "w3"])
    #expect(states.subagents(.session(a)).map(\.type) == ["Explore", "Explore", "Plan"])

    _ = report(&states, .running, ended("w2"))
    #expect(out(states) == ["w1", "w3"])
    _ = report(&states, .running, ended("nobody"))
    #expect(out(states) == ["w1", "w3"], "an end for a worker never seen takes nothing")
  }

  /// Copilot names a worker and gives no id, so two of one kind share a roster
  /// place. The second start counts, so the first stop pays no Done.
  @Test func twoWorkersUnderOneNameTakeTwoEndsToPayADone() {
    var states = SessionStates()
    _ = report(&states, .running)
    states.report(.done, pid: 99, for: .session(a), isSeen: false)

    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("code-review"))
    #expect(out(states) == ["code-review"], "one place on the roster")
    _ = report(&states, .running, working("code-review"))

    #expect(report(&states, .running, ended("code-review")) == .running, "one is still out")
    #expect(out(states) == ["code-review"])
    #expect(report(&states, .running, ended("code-review")) == .done)
    #expect(out(states).isEmpty)
  }

  /// Two workers under one name are two workers: the chip says two where the
  /// roster holds one place for them, or a pane reads as half as busy as it is.
  @Test func theChipCountsWorkersAndNotRosterPlaces() {
    var states = SessionStates()
    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("code-review"))
    _ = report(&states, .running, started("w1"))
    let workers = states.subagents(.session(a))
    #expect(workers.count == 2, "two places")
    #expect(workers.workerCount == 3, "three workers")
    #expect(workers.first?.occurrenceText == t("subagent.occurrences", 2))
    #expect(workers.last?.occurrenceText == nil, "a place of one says nothing")

    _ = report(&states, .running, ended("code-review"))
    #expect(states.subagents(.session(a)).workerCount == 2)
  }

  /// An agent whose start named a worker and whose stop named none still let
  /// one go. Counted as the agent's own report the place would stand for the
  /// rest of the turn and the Done its Stop owed would never be paid.
  @Test func anEndThatNamesNoWorkerTakesOneOffTheRoster() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    #expect(states[.session(a)] == .running, "the Done is held while one is out")

    let unnamed = SubagentReport(id: SubagentReport.anonymousID, phase: .ended)
    #expect(report(&states, .running, unnamed) == .done, "the last one out pays it")
    #expect(out(states).isEmpty)
  }

  /// A tool call from a worker already on the roster changes nothing, so
  /// the sidebar and a list open over it are not re-rendered per call.
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
    #expect(states.subagents(.session(a)).first?.since == first)

    let stamped = states
    _ = report(&states, .running, working("w1"))
    states.stampChanges(against: stamped, at: first.addingTimeInterval(30))
    #expect(states.subagents(.session(a)).first?.since == first, "it moved, its start did not")
  }

  /// A helper from before workers had names writes a count: each `1` is a worker
  /// of its own and each `-1` takes the last of them.
  @Test func anOlderHelpersCountIsKeptAsUnnamedWorkers() {
    var states = SessionStates()
    let anonymous = SubagentReport.anonymousID
    _ = report(&states, .running, SubagentReport(id: anonymous, phase: .started))
    _ = report(&states, .running, SubagentReport(id: anonymous, phase: .started))
    _ = report(&states, .running, started("w1"))
    #expect(states.subagents(.session(a)).count == 3)
    #expect(states.subagents(.session(a)).map(\.type) == [nil, nil, "Explore"])

    _ = report(&states, .running, SubagentReport(id: anonymous, phase: .ended))
    #expect(states.subagents(.session(a)).map(\.type) == [nil, "Explore"])
    _ = report(&states, .done)
    _ = report(&states, .running, ended("w1"))
    #expect(states[.session(a)] == .running, "an unnamed one is still out")
    #expect(report(&states, .running, SubagentReport(id: anonymous, phase: .ended)) == .done)
  }

  /// While any worker is out the pane is Working: a Done on screen when one
  /// starts gives way, and the last worker out pays that Done again.
  @Test func aWorkerOutLiftsADoneToWorkingAndTheLastOutPaysItBack() {
    var states = SessionStates()
    _ = report(&states, .running)
    states.report(.done, pid: 99, message: "all green", for: .session(a), isSeen: false)

    #expect(report(&states, .running, started("w1")) == .running)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(report(&states, .running, ended("w1")) == .done, "the Done it displaced comes back")
    #expect(states[.session(a)] == .done)
  }

  /// A pane with nothing to show shows Working while a worker is out and nothing
  /// again once the last is in: no Done was displaced, so none is owed.
  @Test func aWorkerOutLiftsNothingToWorkingAndTheLastOutClearsIt() {
    var states = SessionStates()
    #expect(report(&states, .running, started("w1")) == .running)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, ended("w1")) == .idle)
    #expect(states[.session(a)] == nil)
    #expect(states.isEmpty, "nothing left behind")
  }

  /// The lift is the worker's, not the agent's: once the agent itself
  /// reports Working, the last worker out leaves that Working standing.
  @Test func anAgentsOwnWorkingOutlivesTheWorkerThatLiftedIt() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    #expect(report(&states, .running) == .running)
    #expect(report(&states, .running, ended("w1")) == .running)
    #expect(states[.session(a)] == .running, "the agent said so itself")
    #expect(report(&states, .done) == .done)
  }

  /// A Waiting outranks Working, and a Failed is about the user: neither
  /// gives way to a worker starting. Only the source clears a Waiting.
  @Test func aWorkerStartingOrEndingLeavesAWaitingOrAFailureAlone() {
    for held in [SessionState.attention, .error] {
      for tick in [started("w2"), ended("w1")] {
        var states = SessionStates()
        _ = report(&states, .running, started("w1"))
        _ = report(&states, held)
        #expect(states[.session(a)] == held)

        #expect(report(&states, .running, tick) == nil, "\(held) \(tick.phase): no news")
        #expect(states[.session(a)] == held, "the prompt is still on screen")
      }
    }
  }

  /// The card's message line comes from the note, so a tick that leaves the
  /// Waiting alone has to leave what it says alone too.
  @Test func aWorkerTickKeepsWhatTheWaitingSaid() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    states.report(
      .attention, pid: 99, message: "Needs Bash", for: .session(a), isSeen: false)
    #expect(states.notes[.session(a)]?.message == "Needs Bash")

    _ = report(&states, .running, ended("w1"))

    #expect(states[.session(a)] == .attention)
    #expect(states.notes[.session(a)]?.message == "Needs Bash", "the prompt is still the news")
  }

  /// A prompt raised inside a worker is a prompt, and it is that worker's
  /// next tool call that says it was answered. Nothing else moves it.
  @Test func aWaitingRaisedInsideAWorkerIsClearedByThatWorkersNextToolCallAlone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .running, started("w2"))
    let prompt = SubagentReport(id: "w1", type: "Explore", phase: .working)
    #expect(report(&states, .attention, prompt) == .attention)
    #expect(states[.session(a)] == .attention)

    #expect(report(&states, .running, started("w3")) == nil, "another starting is not news")
    #expect(report(&states, .running, working("w2")) == nil, "another's tool call is not")
    #expect(report(&states, .running) == nil, "nor is the main thread moving on")
    #expect(states[.session(a)] == .attention, "the prompt is still on screen")
    #expect(report(&states, .running, working("w1")) == .running, "the answered call runs")
    #expect(states[.session(a)] == .running)
  }

  /// The other way round: a worker's tool call does not answer the main
  /// thread's prompt, and the main thread's own next call does.
  @Test func aWaitingRaisedByTheAgentSurvivesAWorkersToolCall() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .attention)
    #expect(report(&states, .running, working("w1")) == nil)
    #expect(states[.session(a)] == .attention)
    #expect(report(&states, .running) == .running)
  }

  /// A prompt inside a worker that lifted the dot over nothing does not
  /// make the Working the agent's: the last worker out still clears it.
  @Test func aWorkersPromptKeepsWhatItsStartDisplaced() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .attention, SubagentReport(id: "w1", phase: .working))
    _ = report(&states, .running, working("w1"))
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, ended("w1")) == .idle, "the agent never spoke")
    #expect(states.isEmpty)
  }

  /// Failed is about the user: a worker's tool call leaves it standing, and
  /// a worker's prompt over it, answered and ended, puts it back unannounced.
  @Test func aFailureStandsThroughAWorkersToolCallsAndComesBackAfterItsPrompt() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .error)
    #expect(out(states).isEmpty, "a failure settles the turn")
    #expect(report(&states, .running, working("w1")) == nil, "a late worker changes nothing")
    #expect(states[.session(a)] == .error)
    #expect(out(states) == ["w1"], "though it is back on the roster")

    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .error)
  }

  /// A worker first seen at a tool call, its start unseen, lifts as a start
  /// does, and the last one out still gives back what it displaced.
  @Test func aWorkerFirstSeenAtAToolCallLiftsAsAStartDoes() {
    var overDone = SessionStates()
    _ = report(&overDone, .running)
    _ = report(&overDone, .done)
    #expect(report(&overDone, .running, working("w1")) == .running)
    #expect(report(&overDone, .running, ended("w1")) == .done)

    var overNothing = SessionStates()
    #expect(report(&overNothing, .running, working("w1")) == .running)
    #expect(report(&overNothing, .running, ended("w1")) == .idle)
    #expect(overNothing.isEmpty)
  }

  /// The Done its agent owed is still paid at the last worker out, a Waiting
  /// being about the turn that has now ended.
  @Test func theOwedDoneOutranksAWaitingLeftOver() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    _ = report(&states, .attention)
    #expect(report(&states, .running, ended("w1")) == .done)
  }

  /// A worker whose start went unseen, the app or its hooks arriving after
  /// it: its ending pays nothing and moves nothing.
  @Test func aWorkerEndingAfterAnUnseenStartLeavesADoneOrAFailureAlone() {
    for finished in [SessionState.done, .error] {
      var states = SessionStates()
      _ = report(&states, .running)
      states.report(finished, pid: 99, message: "all green", for: .session(a), isSeen: false)

      #expect(report(&states, .running, ended("w1")) == nil, "\(finished): no news")
      #expect(states[.session(a)] == finished)
      #expect(states.notes[.session(a)]?.message == "all green", "and the card still says so")
      #expect(states.pids[.session(a)] == nil, "a finished state is about the user, not a pid")
    }
  }

  /// The agent died with a worker out, so no SubagentStop or SessionEnd
  /// arrives to settle it; the shell's own end of that command has to.
  @Test func theShellsCommandEndingSettlesWorkersItsDeadAgentLeftOut() {
    var engineFirst = SessionStates()
    _ = report(&engineFirst, .running, started("w1"))
    engineFirst.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(out(engineFirst).isEmpty)
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
    states.processGone(99)
    #expect(out(states).isEmpty)
    #expect(report(&states, .done) == .done, "the held Done went with the process")
  }

  /// Claude fires no hook on Ctrl+C and the killed workers send no stop, so the
  /// next turn's prompt is what says the last turn's roster is gone.
  @Test func aNewTurnClearsWhatTheLastTurnLeftOut() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .done)
    #expect(states[.session(a)] == .running, "held for the worker")

    #expect(
      states.report(.running, pid: 99, startsTurn: true, for: .session(a), isSeen: false)
        == .running)
    #expect(out(states).isEmpty)
    #expect(report(&states, .done) == .done, "the new turn owes nothing from the last")

    var lifted = SessionStates()
    _ = report(&lifted, .running, started("w1"))
    _ = lifted.report(.running, pid: 99, startsTurn: true, for: .session(a), isSeen: false)
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

  /// A Stop held for a worker does not turn a failure the worker's prompt
  /// covered into a Done: the failure is what the last one out puts back.
  @Test func aHeldStopLeavesAFailureAWorkersPromptCoveredAlone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .error)
    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)

    #expect(report(&states, .done) == nil, "not news while the prompt is up")
    #expect(report(&states, .running, working("w1")) == .running, "answered")
    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .error, "the failure, not the Done")
  }

  /// A failure standing uncovered is left alone by a held Stop as well, or
  /// the Working hides it and the last worker out pays it back as a Done.
  @Test func aHeldStopLeavesAStandingFailureAlone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .error)
    #expect(report(&states, .running, working("w1")) == nil, "a failure stands to mere work")

    #expect(report(&states, .done) == nil, "not news over the failure")
    #expect(states[.session(a)] == .error, "no Working over a failure nobody dealt with")
    #expect(report(&states, .running, ended("w1")) == nil, "nothing owed to put back")
    #expect(states[.session(a)] == .error, "the failure, not a Done")
  }

  /// An unnamed worker's tool call is one already on the roster, not a new
  /// one: a fresh place per call would grow the roster all turn.
  @Test func anUnnamedWorkersToolCallTakesAPlaceAlreadyOut() {
    var states = SessionStates()
    let call = SubagentReport(id: SubagentReport.anonymousID, phase: .working)
    _ = report(&states, .running, call)
    _ = report(&states, .running, call)
    #expect(out(states).count == 1)
  }

  /// An older helper names no worker, so each unnamed one asks under its own
  /// place on the roster: one end does not answer another's prompt.
  @Test func eachUnnamedWorkersPromptIsItsOwn() {
    var states = SessionStates()
    let anonymous = SubagentReport(id: SubagentReport.anonymousID, phase: .started)
    _ = report(&states, .running, anonymous)
    #expect(report(&states, .attention, anonymous) == .attention)
    #expect(report(&states, .attention, anonymous) == .attention)

    let ended = SubagentReport(id: SubagentReport.anonymousID, phase: .ended)
    #expect(report(&states, .running, ended) == nil, "the other is still asking")
    #expect(states[.session(a)] == .attention)
    #expect(report(&states, .running, ended) == .running, "both answered")
  }

  /// The agent's own Working takes the dot back for itself whether or not
  /// another thread's prompt still holds the dot: else the last worker out
  /// puts back what the turn began over, and a Done fires mid-turn.
  @Test func theAgentsOwnWorkingGivesUpWhatAWorkerDisplacedEvenUnanswered() {
    var overDone = SessionStates()
    _ = report(&overDone, .running)
    overDone.report(.done, pid: 99, for: .session(a), isSeen: false)
    _ = report(&overDone, .running, started("w1"))
    _ = report(&overDone, .running, started("w2"))
    _ = report(&overDone, .attention, SubagentReport(id: "w1", phase: .working))

    #expect(report(&overDone, .running) == nil, "w1 is still asking")
    #expect(report(&overDone, .running, ended("w2")) == nil)
    #expect(report(&overDone, .running, ended("w1")) == .running, "the agent said Working")
    #expect(overDone[.session(a)] == .running, "no Done banner in the middle of a turn")

    var overNothing = SessionStates()
    _ = report(&overNothing, .running, started("w1"))
    _ = report(&overNothing, .attention, SubagentReport(id: "w1", phase: .working))
    #expect(report(&overNothing, .running) == nil, "w1 is still asking")
    #expect(report(&overNothing, .running, ended("w1")) == .running, "not a blank dot")
    #expect(overNothing[.session(a)] == .running)
  }

  /// Copilot's two workers of one kind share one roster place and no report
  /// says which of them made it, so neither an end nor a tool call under that
  /// place can answer a prompt raised there while it is still on screen.
  @Test func aPromptUnderASharedPlaceStandsUntilItsLastWorkerIsOut() {
    var byEnd = SessionStates()
    _ = report(&byEnd, .running, started("code-review"))
    _ = report(&byEnd, .running, started("code-review"))
    byEnd.report(
      .attention, pid: 99, message: "Needs Bash",
      subagent: SubagentReport(id: "code-review", phase: .working), for: .session(a),
      isSeen: false)
    #expect(byEnd[.session(a)] == .attention)

    #expect(report(&byEnd, .running, ended("code-review")) == nil, "one of the two is still out")
    #expect(byEnd[.session(a)] == .attention, "the prompt is still on screen")
    #expect(byEnd.notes[.session(a)]?.message == "Needs Bash")
    #expect(report(&byEnd, .running, ended("code-review")) == .idle, "the last one out")

    var byToolCall = SessionStates()
    _ = report(&byToolCall, .running, started("code-review"))
    _ = report(&byToolCall, .running, started("code-review"))
    _ = report(&byToolCall, .attention, SubagentReport(id: "code-review", phase: .working))
    #expect(report(&byToolCall, .running, working("code-review")) == nil, "which of them called")
    #expect(byToolCall[.session(a)] == .attention)
  }

  /// A failure a worker's prompt covered comes back with what the failure
  /// said: the card reads the note against the state it is shown for, so a
  /// note left saying anything else leaves Failed with no line at all.
  @Test func aRestoredFailureKeepsWhatTheFailureSaid() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    states.report(.error, pid: 99, message: "build failed", for: .session(a), isSeen: false)
    _ = report(&states, .running, working("w1"))
    states.report(
      .attention, pid: 99, message: "Needs Bash",
      subagent: SubagentReport(id: "w1", phase: .working), for: .session(a), isSeen: false)
    _ = report(&states, .running, working("w1"))

    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .error)
    #expect(states.notes[.session(a)]?.describing(.error)?.message == "build failed")
  }

  /// The user's clear takes the roster too: a Working dot cleared by hand
  /// must not come back at the next worker's tool call as if nothing happened.
  @Test func theUsersClearTakesTheRoster() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    states.clear(.session(a))
    #expect(out(states).isEmpty)
    #expect(states.isEmpty)
  }
}

@Suite
struct NotificationTitleTests {
  @Test func theTitlePutsTheSubjectBeforeWhereItIs() {
    #expect(
      NotificationPolicy.title(subject: "claude", project: "acme", worktree: "feat")
        == "claude · acme › feat")
  }
}
