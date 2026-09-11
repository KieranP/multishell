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
