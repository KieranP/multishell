import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  private func status(
    _ states: inout SessionStates,
    _ state: ProgramStatus.State,
    id: String? = nil,
    app: String? = "claude-code",
    message: String? = nil,
    pid: Int32? = 42,
    atSecond second: Double = 0,
  ) -> SessionState? {
    note(&states, state, id: id, app: app, message: message, pid: pid, atSecond: second)?.state
  }

  private func note(
    _ states: inout SessionStates,
    _ state: ProgramStatus.State,
    id: String? = nil,
    app: String? = "claude-code",
    message: String? = nil,
    pid: Int32? = 42,
    atSecond second: Double = 0,
  ) -> SessionNote? {
    states.apply(
      programStatus: ProgramStatus(state: state, recordID: id, app: app, message: message),
      pid: pid,
      for: .session(a),
      isSeen: false,
      at: Date(timeIntervalSince1970: second),
    )
  }

  @Test func aProgramsOwnReportsMoveTheDotThroughEveryState() {
    var states = SessionStates()

    #expect(status(&states, .working) == .running)
    #expect(states.trackedPIDs == [42])
    #expect(status(&states, .blocked) == .attention)
    #expect(status(&states, .done, message: "Fixed the build") == .done)
    #expect(states.note(.session(a))?.message == "Fixed the build")
    #expect(states.trackedPIDs == [42], "the program is polled while it holds the dot")
    #expect(status(&states, .failed) == .failed)
    #expect(status(&states, .idle) == .idle)
    #expect(states[.session(a)] == nil)
  }

  @Test func aProgramRewordingTheStateItIsInRaisesNothing() {
    var states = SessionStates()
    #expect(status(&states, .working, message: "Reading files") == .running)

    #expect(status(&states, .working, message: "Editing files") == nil)
    #expect(states[.session(a)] == .running)
  }

  @Test func aDoneTheUserSawStaysClearedWhileTheProgramRepeatsIt() {
    var states = SessionStates()
    _ = status(&states, .done)
    states.markSeen(sessions: [a], worktree: nil)

    #expect(status(&states, .done, message: "Summary") == nil)
    #expect(states[.session(a)] == nil)
  }

  @Test func aChildRecordStillWorkingHoldsTheProgramsDoneUntilItClears() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = status(&states, .working, id: "task1")

    #expect(status(&states, .done) == nil, "the dot stays Working")
    #expect(states[.session(a)] == .running)
    #expect(status(&states, .clear, id: "task1") == .done, "the last child out pays it")
  }

  @Test func aChildRecordAskingTheUserMakesThePaneWait() {
    var states = SessionStates()
    _ = status(&states, .working)

    #expect(status(&states, .blocked, id: "remote/plan") == .attention)
    #expect(
      status(&states, .clear, id: "remote") == .running,
      "a clear takes the records under it",
    )
  }

  @Test func aProgramClearingItsRecordsDropsWhatItWasDoingButKeepsAFinish() {
    var states = SessionStates()
    _ = status(&states, .working)
    #expect(status(&states, .clear) == nil)
    #expect(states[.session(a)] == nil)

    _ = status(&states, .failed)
    _ = status(&states, .clear)
    #expect(states[.session(a)] == .failed)
  }

  @Test func anAgentsHookUnderAProgramsStatusListsItsWorkersAndMovesNoDot() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)

    #expect(report(&states, .running, started("w1")) == nil)
    #expect(report(&states, .done) == nil)
    #expect(report(&states, .attention) == nil)
    #expect(states[.session(a)] == .running)
    #expect(workersOut(states) == ["w1"])
  }

  @Test func theShellsOwnReportEndsTheProgramsHoldOnTheDot() {
    var states = SessionStates()
    _ = status(&states, .working)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == .done)
    #expect(report(&states, .running) == .running, "the hooks decide again")
  }

  @Test func theCommandFinishingEndsTheProgramsHoldOnTheDot() {
    var states = SessionStates()
    _ = status(&states, .working)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
    #expect(report(&states, .running) == .running)
  }

  @Test func theProgramsProcessGoingEndsItsHoldOnTheDot() {
    var states = SessionStates()
    _ = status(&states, .blocked)

    states.noteProcessGone(42)

    #expect(states[.session(a)] == nil)
    #expect(report(&states, .running) == .running)
  }

  @Test func aProgramsFirstReportTakesTheDotFromTheShellsCommand() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))

    #expect(status(&states, .idle) == .idle, "an agent at its prompt is not working")
    #expect(states[.session(a)] == nil)
  }

  @Test func aFullResetInAPaneNoProgramHeldMovesNothing() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))

    #expect(status(&states, .clear, app: nil, pid: nil) == nil)
    #expect(states[.session(a)] == .running)
    #expect(states.trackedPIDs == [99])
  }

  @Test func aHeldDoneLandsWithTheMessageTheProgramSentWithIt() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = status(&states, .working, id: "task1")
    _ = status(&states, .done, message: "Fixed the build")

    #expect(status(&states, .clear, id: "task1", app: nil) == .done)
    #expect(states.note(.session(a))?.message == "Fixed the build")
  }

  @Test func theShellsDoneAfterTheProgramsOwnIsNoNewsInEitherOrder() {
    var states = SessionStates()
    _ = status(&states, .done)
    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
    #expect(states[.session(a)] == .done)

    _ = status(&states, .done)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
    #expect(report(&states, .running) == .running, "the hold has ended")
  }

  @Test func aCommandFailingAfterTheProgramsDoneStillFails() {
    var states = SessionStates()
    _ = status(&states, .done)

    #expect(report(&states, .init(state: .failed, isFromShellIntegration: true)) == .failed)
  }

  @Test func engineActivityLeavesTheDotTheProgramHolds() {
    var states = SessionStates()
    _ = status(&states, .idle)

    states.noteActivity(in: a, isSeen: false)

    #expect(states[.session(a)] == nil)
  }

  @Test func theUsersClearEndsTheProgramsHold() {
    var states = SessionStates()
    _ = status(&states, .working)

    states.clear(sessions: [a], worktree: nil)

    #expect(report(&states, .running) == .running)
  }

  @Test func theProgramClearingItsRecordsTakesTheHooksWorkersWithIt() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = report(&states, .running, started("w1"))

    _ = status(&states, .clear, app: nil)

    #expect(workersOut(states).isEmpty)
    #expect(states.trackedPIDs.isEmpty)
  }

  @Test func aReportWithNoForegroundPidKeepsThePidAHookGave() {
    var states = SessionStates()
    _ = report(&states, .running)

    #expect(status(&states, .blocked, pid: nil) == .attention)
    #expect(states.trackedPIDs == [99])
  }

  @Test func aProgramTheCatalogueKnowsAsNoAgentWorksAsACommandDoes() {
    var states = SessionStates()
    _ = status(&states, .working, app: "terraform")
    #expect(!states.isAgentWorking(in: a, commandIsAgent: false))

    _ = status(&states, .working, app: "claude-code")
    #expect(states.isAgentWorking(in: a, commandIsAgent: false))
  }

  @Test func theShellsDoneAfterAProgramFinishedAndClearedIsNoNews() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func theShellsDoneStaysNoNewsWhenTheCommandsEndLandsBetween() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
  }

  @Test func aCommandEndingAfterTheProgramsFinishHandsTheDotBackWithNoShellReport() {
    var states = SessionStates()
    _ = status(&states, .done)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(report(&states, .running) == .running)
  }

  @Test func aDotReturningToTheProgramsWorkKeepsNoWordsOfTheChildThatAsked() {
    var states = SessionStates()
    _ = status(&states, .working, message: "Refactoring")
    _ = status(&states, .blocked, id: "plan", message: "Approve plan?")
    #expect(states.note(.session(a))?.message == "Approve plan?")

    #expect(status(&states, .done, id: "plan", message: "Plan approved") == .running)
    #expect(states.note(.session(a))?.message == nil)
  }

  @Test func aProgramRewordingItsWorkChangesNothingStored() {
    var states = SessionStates()
    _ = status(&states, .working, message: "Reading files")
    let before = states

    _ = status(&states, .working, message: "Editing files")

    #expect(states == before)
  }

  @Test func aCommandsFinishIsTimedFromWhenItsWorkBeganThroughAQuestion() {
    var states = SessionStates()
    _ = status(&states, .working, app: "npm", atSecond: 100)
    _ = status(&states, .blocked, app: "npm", atSecond: 280)
    _ = status(&states, .working, app: "npm", atSecond: 285)

    #expect(note(&states, .done, app: "npm", atSecond: 287)?.duration == 187)
  }

  @Test func anAgentsFinishIsNotTimed() {
    var states = SessionStates()
    _ = status(&states, .working, atSecond: 100)

    #expect(note(&states, .done, atSecond: 103)?.duration == nil)
  }

  @Test func aCommandReportingOnlyItsDoneIsTimedFromTheShellsStartOfIt() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))
    states.stampChanges(against: SessionStates(), at: Date(timeIntervalSince1970: 100))

    #expect(note(&states, .done, app: "mytool", atSecond: 101)?.duration == 1)
  }

  @Test func aChildRecordsFinishLeavingNoRecordMovesNothing() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))
    _ = status(&states, .working, id: "deploy/us", app: "terraform")

    #expect(status(&states, .done, id: "deploy/us", app: "terraform") == nil)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, started("w1")) == nil, "the program still holds")
  }

  @Test func aStrayChildFinishOnAPaneNoProgramHoldsMovesNothing() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))

    #expect(status(&states, .done, id: "x", app: "terraform") == nil)
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .attention) == .attention, "no hold began")
  }

  @Test func theProgramsProcessGoingEndsAHoldThatRestsOnItsDone() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = status(&states, .done)

    states.noteProcessGone(42)

    #expect(report(&states, .running) == .running)
  }

  @Test func aBareFinishAfterIdleIsTimedAsInstant() {
    var states = SessionStates()
    _ = status(&states, .working, app: "npm", atSecond: 100)
    _ = status(&states, .done, app: "npm", atSecond: 101)
    _ = status(&states, .idle, app: "npm", atSecond: 500)

    #expect(note(&states, .done, app: "npm", atSecond: 501)?.duration == 0)
  }

  @Test func aProgramKnownOnlyByItsChildrenIsAtWorkOnceTheLastChildFinishes() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))
    #expect(status(&states, .blocked, id: "deploy/us", app: "terraform") == .attention)

    #expect(status(&states, .done, id: "deploy/us", app: "terraform") == .running)
  }

  @Test func aProgramTheHooksNameAsAnAgentWorksAsThatAgent() {
    var states = SessionStates()
    _ = status(&states, .working, app: "agy-unknown")
    #expect(!states.isAgentWorking(in: a, commandIsAgent: false))

    _ = states.apply(
      .init(state: .running, agentID: "antigravity"),
      pid: 42,
      for: .session(a),
      isSeen: false,
    )

    #expect(states.isAgentWorking(in: a, commandIsAgent: false))
    #expect(states.programAgent(.session(a))?.id == "antigravity")
  }

  @Test func theShellsFailedAfterTheProgramsOwnFailedIsNoNews() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = status(&states, .failed, message: "apply failed")
    states.noteCommandFinished(in: a, exitCode: 1, isSeen: false)

    #expect(report(&states, .init(state: .failed, isFromShellIntegration: true)) == nil)
    #expect(states.note(.session(a))?.message == "apply failed")
  }

  @Test func aDoneTheUserSawStaysClearedAtItsCommandsEnd() {
    var states = SessionStates()
    _ = status(&states, .done)
    states.markSeen(sessions: [a], worktree: nil)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == nil)
  }

  @Test func anAgentItsHooksNamedBeforeItsFirstReportIsKnownToTheHold() {
    var states = SessionStates()
    _ = report(&states, .init(state: .idle, agentID: "antigravity"))

    _ = status(&states, .working, app: "agy-unknown")

    #expect(states.isAgentWorking(in: a, commandIsAgent: false))
  }

  @Test func aSeenDoneStaysClearedWhenTheShellsReportComesBeforeTheCommandsEnd() {
    var states = SessionStates()
    _ = status(&states, .done)
    states.markSeen(sessions: [a], worktree: nil)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == nil)
  }

  @Test func theNextCommandsEndIsNewsWhereNoShellReportCameBetween() {
    var states = SessionStates()
    _ = status(&states, .done)
    states.markSeen(sessions: [a], worktree: nil)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
  }

  @Test func anAgentNamedByItsHooksHasItsUnwordedQuestionWordedAsAnAgents() {
    var states = SessionStates()
    _ = report(&states, .init(state: .idle, agentID: "antigravity"))

    let note = states.apply(
      programStatus: ProgramStatus(state: .blocked, blockedReason: .question, app: "agy-unknown"),
      pid: 42,
      for: .session(a),
      isSeen: false,
      at: Date(timeIntervalSince1970: 0),
    )

    #expect(note?.message == "An agent needs your input")
  }

  @Test func anAgentItsHooksNamedIsForgottenOnceItsProcessGoes() {
    var states = SessionStates()
    _ = report(&states, .init(state: .done, agentID: "gemini"))

    states.noteProcessGone(99)
    _ = status(&states, .working, app: "terraform")

    #expect(!states.isAgentWorking(in: a, commandIsAgent: false))
  }

  @Test func aHoldWhoseReportsNameNoPidPollsTheOneTheHookGave() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, agentID: "claude"))

    _ = status(&states, .done, pid: nil)

    #expect(states.trackedPIDs.contains(99))
  }

  @Test func aHookReportWithNoPidKeepsThePidItsAgentGaveForTheSweep() {
    var states = SessionStates()
    _ = states.apply(
      .init(state: .idle, agentID: "antigravity"),
      pid: 99,
      for: .session(a),
      isSeen: false,
    )
    _ = states.apply(
      .init(state: .idle, agentID: "antigravity"),
      pid: nil,
      for: .session(a),
      isSeen: false,
    )

    states.noteProcessGone(99)
    _ = status(&states, .working, app: "terraform")

    #expect(!states.isAgentWorking(in: a, commandIsAgent: false))
  }

  @Test func aNestedAgentsExitLeavesTheProgramHoldingThePane() {
    var states = SessionStates()
    _ = status(&states, .working)
    _ = states.apply(
      .init(state: .running, agentID: "gemini"),
      pid: 77,
      for: .session(a),
      isSeen: false,
    )

    states.noteProcessGone(77)

    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running) == nil, "the program still holds")
  }

  @Test func aHookNamingAnAgentForAWorktreeKeepsNothing() {
    var states = SessionStates()
    let worktree = Worktree.ID()

    states.apply(
      .init(state: .idle, agentID: "claude"),
      pid: 99,
      for: .worktree(worktree),
      isSeen: false,
    )

    #expect(states == SessionStates())
  }

  @Test func aCommandsEndIsNewsOnceAReportHasMovedTheDotSinceTheProgramLeft() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)
    _ = report(&states, .running)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
  }

  @Test func theShellsDoneIsNewsOnceALaterCommandHasEnded() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)
    states.markSeen(sessions: [a], worktree: nil)
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: true)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == .done)
  }

  @Test func theAgentsSessionEndAfterItsClearLeavesItsFinishAnnounced() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)
    _ = report(&states, .idle)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done, "the program's finish outlives its session end")
    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == nil)
  }

  @Test func aNestedAgentLeavesTheAgentAnUnknownProgramsHooksNamed() {
    var states = SessionStates()
    _ = states.apply(
      .init(state: .idle, agentID: "antigravity"),
      pid: 99,
      for: .session(a),
      isSeen: false,
    )
    _ = status(&states, .working, app: "agy-unknown")
    _ = states.apply(
      .init(state: .running, agentID: "gemini"),
      pid: 77,
      for: .session(a),
      isSeen: false,
    )

    states.noteProcessGone(77)

    #expect(states.programAgent(.session(a))?.id == "antigravity")
  }

  @Test func aHoldWhoseReportsNameNoPidNeverPollsTheShellItself() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))

    _ = status(&states, .done, pid: nil)

    #expect(!states.trackedPIDs.contains(99))
  }

  @Test func aReportNamingNoAppLeavesTheAgentTheHoldBeganWith() {
    var states = SessionStates()
    _ = status(&states, .working, app: "claude-code")

    _ = status(&states, .idle, app: nil)

    #expect(states.programAgent(.session(a))?.id == "claude")
  }

  @Test func aHoldNeverPollsTheShellsPidThroughAHookThatNamedNone() {
    var states = SessionStates()
    _ = report(&states, .init(state: .running, isFromShellIntegration: true))
    _ = states.apply(.init(state: .running), pid: nil, for: .session(a), isSeen: false)

    _ = status(&states, .done, pid: nil)

    #expect(!states.trackedPIDs.contains(99))
  }

  @Test func aNestedAgentsStopLeavesTheHoldingAgentsWorkersListed() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 42)
    _ = states.apply(
      .init(state: .running, worker: started("w1")),
      pid: 42,
      for: .session(a),
      isSeen: false,
    )

    _ = states.apply(
      .init(state: .done, agentID: "codex", workersOut: []),
      pid: 77,
      for: .session(a),
      isSeen: false,
    )

    #expect(workersOut(states) == ["w1"])
  }

  @Test func anUnknownProgramWithNoPidTakesItsOwnHooksAgent() {
    var states = SessionStates()
    _ = status(&states, .working, app: "agy-unknown", pid: nil)

    _ = states.apply(
      .init(state: .running, agentID: "antigravity"),
      pid: 300,
      for: .session(a),
      isSeen: false,
    )

    #expect(states.programAgent(.session(a))?.id == "antigravity")
  }

  @Test func aReportFromAnotherForegroundProcessLeavesTheHoldsPid() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 42)
    _ = status(&states, .working, id: "task1", pid: 400)

    states.noteProcessGone(400)

    #expect(states[.session(a)] == .running)
  }

  @Test func anAgentStartedThroughAWrapperListsItsOwnWorkersUnderItsHold() {
    var states = SessionStates()
    _ = status(&states, .working, app: "codex", pid: 100)

    _ = states.apply(
      .init(state: .running, agentID: "codex", worker: started("w1")),
      pid: 150,
      for: .session(a),
      isSeen: false,
    )

    #expect(workersOut(states) == ["w1"])
  }

  @Test func theAgentsLateStopAfterItsClearIsNoNews() {
    var states = SessionStates()
    _ = status(&states, .done)
    _ = status(&states, .clear, app: nil)

    #expect(report(&states, .init(state: .done, agentID: "claude")) == nil)
    #expect(states[.session(a)] == .done)
  }

  @Test func aProgramsDoneWithBackgroundWorkOutWaitsForTheTurnItsEndWakes() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("shell1"))
    _ = report(&states, .init(state: .done, resumesAfterWorkers: true))

    #expect(status(&states, .done, pid: 99) == nil, "Working while the shell runs")
    #expect(states[.session(a)] == .running)
    #expect(report(&states, .running, ended("shell1")) == nil, "the woken turn pays it")
    #expect(status(&states, .working, pid: 99) == nil)
    #expect(status(&states, .done, pid: 99) == .done)
  }

  @Test func aProgramThatTakesNoTurnForItsWorkersIsPaidByTheLastOneOut() {
    var states = SessionStates()
    _ = status(&states, .working, app: "codex", pid: 99)
    _ = report(&states, .running, started("w1"))

    #expect(status(&states, .done, app: "codex", pid: 99) == nil)
    #expect(report(&states, .running, ended("w1")) == .done)
  }

  @Test func aStopWhoseListEmptiesTheRosterPaysTheHeldDone() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("shell1"))
    _ = status(&states, .done, pid: 99)

    #expect(
      report(&states, .init(state: .done, resumesAfterWorkers: true, workersOut: [])) == .done
    )
  }

  @Test func aCancelledWorkersEndPaysTheHeldDone() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("w1"))
    _ = report(&states, .init(state: .done, resumesAfterWorkers: true))
    _ = status(&states, .done, pid: 99)

    let cancelled = WorkerReport(id: "w1", phase: .ended, wakesAgent: false)
    #expect(report(&states, .running, cancelled) == .done)
  }

  @Test func aDoneHeldOverWorkersIsNotAnnouncedSoTheCommandsEndLandsIt() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("w1"))
    _ = status(&states, .done, pid: 99)
    _ = status(&states, .clear, app: nil)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
  }

  @Test func theShellsReportAndTheCommandsEndAfterAHeldDoneLandIt() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("w1"))
    _ = status(&states, .done, pid: 99)

    _ = report(&states, .init(state: .done, isFromShellIntegration: true))
    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
  }

  @Test func theLastWorkerOutPaysTheHeldDoneWithTheProgramsWords() {
    var states = SessionStates()
    _ = status(&states, .working, app: "codex", pid: 99)
    _ = report(&states, .running, started("w1"))
    _ = status(&states, .done, app: "codex", message: "Implemented X", pid: 99)

    _ = report(&states, .running, ended("w1"))

    #expect(states.note(.session(a)) == SessionNote(state: .done, message: "Implemented X"))
  }

  @Test func aDoneHeldOverWorkersKeepsItsWordsOffTheWorkingNote() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("w1"))
    _ = status(&states, .blocked, message: "Allow?", pid: 99)

    _ = status(&states, .done, message: "Turn summary", pid: 99)

    #expect(states.note(.session(a))?.message == nil)
  }

  private func holdADoneForAWakeThatHasNotCome(_ states: inout SessionStates) {
    _ = status(&states, .working, pid: 99)
    _ = report(&states, .running, started("shell1"))
    _ = report(&states, .init(state: .done, resumesAfterWorkers: true))
    _ = status(&states, .done, pid: 99)
    _ = report(&states, .running, ended("shell1"))
  }

  @Test func theCommandsEndLandsADoneHeldForAWakeThatNeverCame() {
    var states = SessionStates()
    holdADoneForAWakeThatHasNotCome(&states)

    states.noteCommandFinished(in: a, exitCode: 0, isSeen: false)

    #expect(states[.session(a)] == .done)
  }

  @Test func theShellsDoneLandsADoneHeldForAWakeThatNeverCame() {
    var states = SessionStates()
    holdADoneForAWakeThatHasNotCome(&states)

    #expect(report(&states, .init(state: .done, isFromShellIntegration: true)) == .done)
  }

  @Test func aWorkerHeardAfterTheProgramsDoneLandedPutsTheDotBackToWork() {
    var states = SessionStates()
    _ = status(&states, .working, pid: 99)
    _ = status(&states, .done, pid: 99)

    #expect(report(&states, .running, started("w1")) == .running)
  }

  @Test func aReportWithNoPidNeverTakesAnotherAgentsPidFromTheHooks() {
    var states = SessionStates()
    _ = states.apply(
      .init(state: .idle, agentID: "claude"),
      pid: 77,
      for: .session(a),
      isSeen: false,
    )

    _ = status(&states, .working, app: "codex", pid: nil)

    #expect(!states.trackedPIDs.contains(77))
  }

  @Test func aChildRecordNamingTheHooksAgentNeverGivesAnotherAgentsHoldItsPid() {
    var states = SessionStates()
    _ = states.apply(
      .init(state: .idle, agentID: "claude"),
      pid: 77,
      for: .session(a),
      isSeen: false,
    )
    _ = status(&states, .working, app: "codex", pid: nil)

    _ = status(&states, .working, id: "task1", app: "claude-code", pid: nil)

    #expect(!states.trackedPIDs.contains(77))
  }
}
