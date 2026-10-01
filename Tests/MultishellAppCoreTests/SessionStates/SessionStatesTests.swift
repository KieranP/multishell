import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct SessionStatesTests {
  let a = UUID()
  let b = UUID()

  @Test func doneIsAboutTheUserAndClearsWhenSeen() {
    var states = SessionStates()
    states.report(.init(state: .done), pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == .done)
    states.markSeen(sessions: [a], worktree: nil)
    #expect(states[.session(a)] == nil)

    states.report(.init(state: .done), pid: nil, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == nil, "a report about a tab being looked at is seen already")
  }

  @Test func workingAndWaitingStayWhileTheUserLooks() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: 10, for: .session(a), isSeen: true)
    states.report(.init(state: .attention), pid: 11, for: .session(b), isSeen: true)
    states.markSeen(sessions: [a, b], worktree: nil)
    #expect(states[.session(a)] == .running)
    #expect(states[.session(b)] == .attention)
    #expect(states.trackedPIDs == [10, 11])
  }

  /// Claude and Gemini end the old session before starting the new one on
  /// `/clear`, and Esc having interrupted the turn fired no hook.
  @Test func aClearAfterAnInterruptedTurnLeavesThePaneIdle() {
    var states = SessionStates()
    states.report(.init(state: .running, startsTurn: true), pid: 10, for: .session(a), isSeen: true)

    states.report(.init(state: .idle), pid: 10, for: .session(a), isSeen: true)
    states.report(.init(state: .idle, startsSession: true), pid: 10, for: .session(a), isSeen: true)

    #expect(states[.session(a)] == nil)
  }

  /// A failure asks to be dealt with, so only the source reporting something
  /// else, or the user's own clear, takes it.
  @Test func failedSurvivesALookAndTheProcessThatFailed() {
    var states = SessionStates()
    states.report(.init(state: .failed), pid: 7, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == .failed, "reported about a pane being looked at, and it stays")
    states.markSeen(sessions: [a], worktree: nil)
    #expect(states[.session(a)] == .failed)
    states.processGone(7)
    #expect(states[.session(a)] == .failed, "the failure outlives what failed")

    states.report(.init(state: .running), pid: 8, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == .running, "the source reporting again clears it")

    states.report(.init(state: .failed), pid: 9, for: .session(b), isSeen: false)
    states.clear(.session(b))
    #expect(states[.session(b)] == nil, "and so does the user's own clear")
  }

  @Test func theSourceClearsWaitingByReportingAgain() {
    var states = SessionStates()
    states.report(.init(state: .attention), pid: 7, for: .session(a), isSeen: false)
    states.report(.init(state: .running), pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == .running)
    #expect(states.pids[.session(a)] == 7, "the pid survives a report without one")
    states.report(.init(state: .idle), pid: nil, for: .session(a), isSeen: false)
    #expect(states[.session(a)] == nil)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func engineActivityNeverDowngradesAReportedState() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: nil, for: .session(a), isSeen: false)
    states.noteActivity(in: a, isSeen: false)
    #expect(states[.session(a)] == .running, "an agent retitles the tab on every step")

    states.noteActivity(in: b, isSeen: false)
    #expect(states[.session(b)] == .done, "a plain shell's bell is the old dot")
    states.noteActivity(in: UUID(), isSeen: true)
    #expect(states.states.count == 2)
  }

  @Test func aFinishedCommandOutranksAReport() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: 5, for: .session(a), isSeen: false)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(states[.session(a)] == .done, "the agent exited, and the user has not seen that")
    #expect(states.trackedPIDs.isEmpty)

    states.report(.init(state: .attention), pid: 6, for: .session(b), isSeen: true)
    states.noteCommandFinished(in: b, exitCode: 0, isSeen: true)
    #expect(states[.session(b)] == nil)
  }

  @Test func aNonZeroExitIsFailedAndOutlivesAnUnseenDone() {
    var states = SessionStates()
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    states.noteCommandFinished(in: a, exitCode: 2, isSeen: false)
    #expect(states[.session(a)] == .failed)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(states[.session(a)] == .failed, "a later success does not hide the failure")
    states.noteCommandFinished(in: a, exitCode: 130, isSeen: false)
    #expect(states[.session(a)] == .failed)

    states.noteCommandFinished(in: b, exitCode: 130, isSeen: false)
    #expect(states[.session(b)] == .done, "Ctrl+C is not a failure")
    states.report(.init(state: .failed), pid: nil, for: .worktree("/w"), isSeen: false)
    #expect(states[.worktree("/w")] == .failed)
    states.markSeen(sessions: [a], worktree: "/w")
    #expect(
      states[.session(a)] == .failed && states[.worktree("/w")] == .failed,
      "a look is not dealing with a failure")
    states.clear(sessions: [a], worktree: "/w")
    #expect(states[.session(a)] == nil && states[.worktree("/w")] == nil, "clearing by hand is")
  }

  @Test func aGoneProcessTakesWorkingAndWaitingButNotDone() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: 42, for: .session(a), isSeen: false)
    states.report(.init(state: .attention), pid: 42, for: .worktree("/w"), isSeen: false)
    states.report(.init(state: .done), pid: nil, for: .session(b), isSeen: false)

    states.processGone(42)

    #expect(states[.session(a)] == nil)
    #expect(states[.worktree("/w")] == nil)
    #expect(states[.session(b)] == .done)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func theMostUrgentOfATabOrWorktreeWins() {
    var states = SessionStates()
    states.report(.init(state: .done), pid: nil, for: .session(a), isSeen: false)
    states.report(.init(state: .running), pid: nil, for: .session(b), isSeen: false)
    #expect(states.state(ofSessions: [a, b]) == .running)
    states.report(.init(state: .attention), pid: nil, for: .worktree("/w"), isSeen: false)
    #expect(states.state(ofWorktree: "/w", sessions: [a, b]) == .attention)
    #expect(states.state(ofWorktree: "/other", sessions: []) == nil)
    #expect(states.workingSessionIDs == [b], "worktree-level Working is nobody's shell")
  }

  @Test func retainDropsWhatNoLongerExists() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: 1, for: .session(a), isSeen: false)
    states.report(.init(state: .running), pid: 2, for: .session(b), isSeen: false)
    states.report(.init(state: .done), pid: nil, for: .worktree("/w"), isSeen: false)
    states.retain(sessions: [a], worktrees: [])
    #expect(states.states.keys.contains(.session(a)))
    #expect(states.states.count == 1)
    #expect(states.trackedPIDs == [1])
  }

  @Test func aStateThatMovesIsStampedAndOneThatRepeatsIsNot() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var states = SessionStates()

    var stamped = states
    stamped.report(.init(state: .running), pid: 1, for: .session(a), isSeen: false)
    stamped.stampChanges(against: states, at: start)
    #expect(stamped.sinceDates[.session(a)] == start)

    // An agent reports Working on every tool call; how long it has been
    // working must not keep resetting.
    states = stamped
    var again = states
    again.report(.init(state: .running), pid: 1, for: .session(a), isSeen: false)
    again.stampChanges(against: states, at: start.addingTimeInterval(60))
    #expect(again.sinceDates[.session(a)] == start, "the state did not move")

    states = again
    var finished = states
    finished.report(.init(state: .done), pid: nil, for: .session(a), isSeen: false)
    finished.stampChanges(against: states, at: start.addingTimeInterval(90))
    #expect(finished.sinceDates[.session(a)] == start.addingTimeInterval(90))
  }

  /// Idle is never a stored state, so the board reads how long a pane has
  /// been idle from the stamp its last state left behind.
  @Test func goingBackToNothingIsStampedTooAndDropsTheNote() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var states = SessionStates()
    states.report(
      .init(state: .attention, message: "Needs Bash"), pid: 1, for: .session(a), isSeen: false)
    #expect(states.notes[.session(a)]?.message == "Needs Bash")

    var cleared = states
    cleared.markSeen(sessions: [a], worktree: nil)
    cleared.report(.init(state: .idle), pid: nil, for: .session(a), isSeen: false)
    cleared.stampChanges(against: states, at: start)
    #expect(cleared[.session(a)] == nil)
    #expect(cleared.sinceDates[.session(a)] == start)
    #expect(cleared.notes[.session(a)] == nil, "nothing left for the note to be about")
  }

  @Test func aNoteCarriesTheStateItArrivedWith() {
    var states = SessionStates()
    states.report(.init(state: .done, duration: 194), pid: nil, for: .session(a), isSeen: false)
    let note = states.notes[.session(a)]
    #expect(note?.state == .done)
    #expect(note?.duration == 194)
    #expect(note?.matching(.done) == note)
    #expect(note?.matching(.attention) == nil, "it stopped describing the pane")
  }

  @Test func aReportAboutAShownTabLeavesNoNote() {
    var states = SessionStates()
    states.report(.init(state: .done, duration: 3), pid: nil, for: .session(a), isSeen: true)
    #expect(states[.session(a)] == nil)
    #expect(states.notes[.session(a)] == nil)
  }

  @Test func retainDropsTheStampsAndNotesWithTheirKeys() {
    var states = SessionStates()
    states.report(
      .init(state: .running, message: "building"), pid: 1, for: .session(a), isSeen: false)
    states.report(
      .init(state: .running, message: "testing"), pid: 2, for: .session(b), isSeen: false)
    states.stampChanges(against: SessionStates(), at: Date(timeIntervalSince1970: 1))
    states.retain(sessions: [a], worktrees: [])
    #expect(states.sinceDates.keys.map { $0 } == [.session(a)])
    #expect(states.notes.keys.map { $0 } == [.session(a)])
  }

  @Test func clearingByHandTakesEverythingForTheKeys() {
    var states = SessionStates()
    states.report(.init(state: .running), pid: 1, for: .session(a), isSeen: false)
    states.report(.init(state: .attention), pid: 2, for: .worktree("/w"), isSeen: false)
    states.clear(sessions: [a], worktree: "/w")
    #expect(states.showsNothing && states.trackedPIDs.isEmpty)
  }

  func shellGone(_ states: inout SessionStates, _ pid: Int32) -> [SessionState?] {
    states.endings(ofShell: pid).map {
      states.report(
        .init(state: .running, subagent: $0.report), pid: nil, for: $0.key, isSeen: false)
    }
  }
}
