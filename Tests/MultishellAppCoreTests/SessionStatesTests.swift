import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Who clears what, on the plain value the model and the views read.
@Suite
struct SessionStatesTests {
  private let a = UUID()
  private let b = UUID()

  @Test func doneIsAboutTheUserAndClearsWhenShown() {
    var states = SessionStates()
    states.report(.done, pid: nil, for: .session(a), isShown: false)
    #expect(states[.session(a)] == .done)
    states.markSeen(sessions: [a], worktree: nil)
    #expect(states[.session(a)] == nil)

    states.report(.done, pid: nil, for: .session(a), isShown: true)
    #expect(states[.session(a)] == nil, "a report about the shown tab has been seen already")
  }

  @Test func workingAndWaitingStayWhileTheUserLooks() {
    var states = SessionStates()
    states.report(.running, pid: 10, for: .session(a), isShown: true)
    states.report(.attention, pid: 11, for: .session(b), isShown: true)
    states.markSeen(sessions: [a, b], worktree: nil)
    #expect(states[.session(a)] == .running)
    #expect(states[.session(b)] == .attention)
    #expect(states.trackedPIDs == [10, 11])
  }

  @Test func theSourceClearsWaitingByReportingAgain() {
    var states = SessionStates()
    states.report(.attention, pid: 7, for: .session(a), isShown: false)
    states.report(.running, pid: nil, for: .session(a), isShown: false)
    #expect(states[.session(a)] == .running)
    #expect(states.pids[.session(a)] == 7, "the pid survives a report without one")
    states.report(.idle, pid: nil, for: .session(a), isShown: false)
    #expect(states[.session(a)] == nil)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func engineActivityNeverDowngradesAReportedState() {
    var states = SessionStates()
    states.report(.running, pid: nil, for: .session(a), isShown: false)
    states.noteActivity(in: a, isShown: false)
    #expect(states[.session(a)] == .running, "an agent retitles the tab on every step")

    states.noteActivity(in: b, isShown: false)
    #expect(states[.session(b)] == .done, "a plain shell's bell is the old dot")
    states.noteActivity(in: UUID(), isShown: true)
    #expect(states.states.count == 2)
  }

  @Test func aFinishedCommandOutranksAReport() {
    var states = SessionStates()
    states.report(.running, pid: 5, for: .session(a), isShown: false)
    states.noteCommandFinished(in: a, exitCode: 0, isShown: false)
    #expect(states[.session(a)] == .done, "the agent exited, and the user has not seen that")
    #expect(states.trackedPIDs.isEmpty)

    states.report(.attention, pid: 6, for: .session(b), isShown: true)
    states.noteCommandFinished(in: b, exitCode: 0, isShown: true)
    #expect(states[.session(b)] == nil)
  }

  @Test func aNonZeroExitIsFailedAndOutlivesAnUnseenDone() {
    var states = SessionStates()
    states.noteCommandFinished(in: a, exitCode: 0, isShown: false)
    states.noteCommandFinished(in: a, exitCode: 2, isShown: false)
    #expect(states[.session(a)] == .error)
    states.noteCommandFinished(in: a, exitCode: 0, isShown: false)
    #expect(states[.session(a)] == .error, "a later success does not hide the failure")
    states.noteCommandFinished(in: a, exitCode: 130, isShown: false)
    #expect(states[.session(a)] == .error)

    states.noteCommandFinished(in: b, exitCode: 130, isShown: false)
    #expect(states[.session(b)] == .done, "Ctrl+C is not a failure")
    states.report(.error, pid: nil, for: .worktree("/w"), isShown: false)
    #expect(states[.worktree("/w")] == .error)
    states.markSeen(sessions: [a], worktree: "/w")
    #expect(states.isEmpty || states.states.keys.contains(.session(b)))
    #expect(states[.session(a)] == nil && states[.worktree("/w")] == nil)
  }

  @Test func aGoneProcessTakesWorkingAndWaitingButNotDone() {
    var states = SessionStates()
    states.report(.running, pid: 42, for: .session(a), isShown: false)
    states.report(.attention, pid: 42, for: .worktree("/w"), isShown: false)
    states.report(.done, pid: nil, for: .session(b), isShown: false)

    states.processGone(42)

    #expect(states[.session(a)] == nil)
    #expect(states[.worktree("/w")] == nil)
    #expect(states[.session(b)] == .done)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func theMostUrgentOfATabOrWorktreeWins() {
    var states = SessionStates()
    states.report(.done, pid: nil, for: .session(a), isShown: false)
    states.report(.running, pid: nil, for: .session(b), isShown: false)
    #expect(states.state(ofSessions: [a, b]) == .running)
    states.report(.attention, pid: nil, for: .worktree("/w"), isShown: false)
    #expect(states.state(ofWorktree: "/w", sessions: [a, b]) == .attention)
    #expect(states.state(ofWorktree: "/other", sessions: []) == nil)
    #expect(states.workingSessionCount == 1, "worktree-level Working is nobody's shell")
  }

  @Test func retainDropsWhatNoLongerExists() {
    var states = SessionStates()
    states.report(.running, pid: 1, for: .session(a), isShown: false)
    states.report(.running, pid: 2, for: .session(b), isShown: false)
    states.report(.done, pid: nil, for: .worktree("/w"), isShown: false)
    states.retain(sessions: [a], worktrees: [])
    #expect(states.states.keys.contains(.session(a)))
    #expect(states.states.count == 1)
    #expect(states.trackedPIDs == [1])
  }

  @Test func clearingByHandTakesEverythingForTheKeys() {
    var states = SessionStates()
    states.report(.running, pid: 1, for: .session(a), isShown: false)
    states.report(.attention, pid: 2, for: .worktree("/w"), isShown: false)
    states.clear(sessions: [a], worktree: "/w")
    #expect(states.isEmpty && states.trackedPIDs.isEmpty)
  }
}

@Suite
struct NotificationPolicyTests {
  @Test func aShownTabInAnActiveAppIsNotWorthABanner() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .attention, preference: .attentionAndDone, isShown: true, appIsActive: true))
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: .attentionAndDone, isShown: true, appIsActive: false),
      "the user is in another app")
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: .attentionAndDone, isShown: false, appIsActive: true))
    #expect(
      !NotificationPolicy.shouldNotify(
        .done, preference: .attentionOnly, isShown: false, appIsActive: true))
    #expect(
      !NotificationPolicy.shouldNotify(
        .running, preference: .attentionAndDone, isShown: false, appIsActive: false))
  }

  @Test func aShortCommandDoesNotEarnABannerButAnAgentOrALongOneDoes() {
    #expect(
      !NotificationPolicy.shouldNotify(
        .done, preference: .attentionAndDone, isShown: false, appIsActive: true, duration: 0.2),
      "ls in a background tab")
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: .attentionAndDone, isShown: false, appIsActive: true, duration: 45))
    #expect(
      NotificationPolicy.shouldNotify(
        .done, preference: .attentionAndDone, isShown: false, appIsActive: true, duration: nil),
      "an agent's Stop hook carries no duration")
    #expect(
      NotificationPolicy.shouldNotify(
        .attention, preference: .attentionAndDone, isShown: false, appIsActive: true,
        duration: 0.1),
      "waiting is never short")
  }

  @Test func theBodyPrefersTheSourcesMessage() {
    #expect(NotificationPolicy.body(for: .attention, message: "Needs Bash") == "Needs Bash")
    #expect(NotificationPolicy.body(for: .attention, message: "") == "Waiting for your input.")
    #expect(NotificationPolicy.body(for: .done, message: nil) == "Finished.")
  }
}
