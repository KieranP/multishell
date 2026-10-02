import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
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
    #expect(overNothing.showsNothing)
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

  /// A Waiting outranks Working, and a Failed is about the user: neither
  /// gives way to a worker starting. Only the source clears a Waiting.
  @Test func aWorkerStartingOrEndingLeavesAWaitingOrAFailureAlone() {
    for held in [SessionState.attention, .failed] {
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
      .init(state: .attention, message: "Needs Bash"), pid: 99, for: .session(a), isSeen: false)
    #expect(states.notes[.session(a)]?.message == "Needs Bash")

    _ = report(&states, .running, ended("w1"))

    #expect(states[.session(a)] == .attention)
    #expect(states.notes[.session(a)]?.message == "Needs Bash", "the prompt is still the news")
  }

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
    #expect(states.showsNothing)
  }

  /// Failed is about the user: a worker's tool call leaves it standing, and
  /// a worker's prompt over it, answered and ended, puts it back unannounced.
  @Test func aFailureStandsThroughAWorkersToolCallsAndComesBackAfterItsPrompt() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .failed)
    #expect(workersOut(states).isEmpty, "a failure settles the turn")
    #expect(report(&states, .running, working("w1")) == nil, "a late worker changes nothing")
    #expect(states[.session(a)] == .failed)
    #expect(workersOut(states) == ["w1"], "though it is back on the roster")

    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)
    #expect(report(&states, .running, working("w1")) == .running)
    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .failed)
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
    for finished in [SessionState.done, .failed] {
      var states = SessionStates()
      _ = report(&states, .running)
      states.report(
        .init(state: finished, message: "all green"), pid: 99, for: .session(a), isSeen: false)

      #expect(report(&states, .running, ended("w1")) == nil, "\(finished): no news")
      #expect(states[.session(a)] == finished)
      #expect(states.notes[.session(a)]?.message == "all green", "and the card still says so")
      #expect(states.pids[.session(a)] == nil, "a finished state is about the user, not a pid")
    }
  }

  /// A Stop held for a worker does not turn a failure the worker's prompt
  /// covered into a Done: the failure is what the last one out puts back.
  @Test func aHeldStopLeavesAFailureAWorkersPromptCoveredAlone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .failed)
    #expect(report(&states, .attention, SubagentReport(id: "w1", phase: .working)) == .attention)

    #expect(report(&states, .done) == nil, "not news while the prompt is up")
    #expect(report(&states, .running, working("w1")) == .running, "answered")
    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .failed, "the failure, not the Done")
  }

  /// A failure standing uncovered is left alone by a held Stop as well, or
  /// the Working hides it and the last worker out pays it back as a Done.
  @Test func aHeldStopLeavesAStandingFailureAlone() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .failed)
    #expect(report(&states, .running, working("w1")) == nil, "a failure stands to mere work")

    #expect(report(&states, .done) == nil, "not news over the failure")
    #expect(states[.session(a)] == .failed, "no Working over a failure nobody dealt with")
    #expect(report(&states, .running, ended("w1")) == nil, "nothing owed to put back")
    #expect(states[.session(a)] == .failed, "the failure, not a Done")
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

  /// The agent's own Working reclaims the dot even under another thread's prompt, or the
  /// last worker out puts back what the turn began over and a Done fires mid-turn.
  @Test func theAgentsOwnWorkingGivesUpWhatAWorkerDisplacedEvenUnanswered() {
    var overDone = SessionStates()
    _ = report(&overDone, .running)
    overDone.report(.init(state: .done), pid: 99, for: .session(a), isSeen: false)
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

  /// Copilot's two workers of one kind share a place and no report says which one made
  /// it, so neither an end nor a tool call there answers a prompt raised under it.
  @Test func aPromptUnderASharedPlaceStandsUntilItsLastWorkerIsOut() {
    var byEnd = SessionStates()
    _ = report(&byEnd, .running, started("code-review"))
    _ = report(&byEnd, .running, started("code-review"))
    byEnd.report(
      .init(
        state: .attention, message: "Needs Bash",
        subagent: SubagentReport(id: "code-review", phase: .working)), pid: 99, for: .session(a),
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

  /// The card reads the note against the state it shows, so a restored failure whose note
  /// said anything else would show Failed with no line at all.
  @Test func aRestoredFailureKeepsWhatTheFailureSaid() {
    var states = SessionStates()
    _ = report(&states, .running, started("w1"))
    states.report(
      .init(state: .failed, message: "build failed"), pid: 99, for: .session(a), isSeen: false)
    _ = report(&states, .running, working("w1"))
    states.report(
      .init(
        state: .attention, message: "Needs Bash",
        subagent: SubagentReport(id: "w1", phase: .working)), pid: 99, for: .session(a),
      isSeen: false)
    _ = report(&states, .running, working("w1"))

    #expect(report(&states, .running, ended("w1")) == nil, "put back without a banner")
    #expect(states[.session(a)] == .failed)
    #expect(states.notes[.session(a)]?.matching(.failed)?.message == "build failed")
  }

  @Test func aRestoredFailureKeepsWhenItFailed() {
    var states = SessionStates()
    var clock = 1000.0
    func step(_ change: (inout SessionStates) -> Void) {
      let before = states
      change(&states)
      states.stampChanges(against: before, at: Date(timeIntervalSince1970: clock))
      clock += 10
    }

    step { _ = report(&$0, .running, started("w1")) }
    step {
      $0.report(
        .init(state: .failed, message: "build failed"), pid: 99, for: .session(a), isSeen: false)
    }
    step {
      $0.report(
        .init(
          state: .attention, message: "Needs Bash",
          subagent: SubagentReport(id: "w1", phase: .working)), pid: 99, for: .session(a),
        isSeen: false)
    }
    step { _ = report(&$0, .running, working("w1")) }
    step { _ = report(&$0, .running, ended("w1")) }

    #expect(states[.session(a)] == .failed)
    #expect(states.since(.session(a)) == Date(timeIntervalSince1970: 1010))
  }
}
