import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelProgramStatusTests {
  private func send(
    _ status: ProgramStatus,
    to id: TerminalSession.ID,
    in harness: Harness,
    from pid: Int32? = 4242,
  ) {
    harness.engine.delegate?.terminalHost(harness.engine, didReceive: status, from: pid, in: id)
  }

  @Test func claudesReportNamesItTheAgentAtThePrompt() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()

    send(.init(state: .idle, app: "claude-code"), to: tab.focusedSessionID, in: harness)

    #expect(harness.model.agentIDAtThePrompt(of: tab) == AgentCatalogue.claudeID)
  }

  @Test func aProgramTheCatalogueDoesNotKnowMovesTheDotAndNamesNoAgent() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()

    send(.init(state: .working, app: "terraform"), to: tab.focusedSessionID, in: harness)

    #expect(harness.model.agentIDAtThePrompt(of: tab) == nil)
    #expect(harness.model.state(of: tab) == .running)
  }

  @Test func aBackgroundPanesProgramRaisesOneBannerAtItsDoneWithItsMessage() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()
    let id = tab.focusedSessionID

    send(.init(state: .working, app: "codex"), to: id, in: harness)
    send(.init(state: .done, app: "codex", message: "Tests pass"), to: id, in: harness)
    send(.init(state: .done, app: "codex", message: "Tests pass"), to: id, in: harness)

    #expect(harness.notifier.posted.map(\.body) == ["Tests pass"])
    #expect(harness.notifier.posted.first?.key == .session(id))
  }

  @Test func aQuestionTheProgramLeftUnwordedIsWordedOnTheBanner() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()

    send(
      .init(state: .blocked, blockedReason: .question, app: "codex"),
      to: tab.focusedSessionID,
      in: harness,
    )

    #expect(harness.notifier.posted.first?.body == "An agent needs your input")
    #expect(harness.model.state(of: tab) == .attention)
  }

  @Test func aReportForAClosedSessionIsDropped() {
    let (harness, session) = Harness.withOnePane()
    harness.engine.delegate?.terminalHost(harness.engine, didExit: session.id)

    send(.init(state: .working, app: "claude-code"), to: session.id, in: harness)

    #expect(harness.model.sessionStates.showsNothing)
    #expect(harness.model.reportedAgents.isEmpty)
  }

  @Test func aChildRecordNamingAnotherAppLeavesTheAgentAtThePrompt() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    let id = tab.focusedSessionID
    send(.init(state: .working, app: "claude-code"), to: id, in: harness)

    send(.init(state: .working, recordID: "task1", app: "codex"), to: id, in: harness)
    send(.init(state: .clear, recordID: "task1", app: "codex"), to: id, in: harness)

    #expect(harness.model.agentIDAtThePrompt(of: tab) == AgentCatalogue.claudeID)
  }

  @Test func aNestedAgentsHookLeavesTheHoldingProgramsAgentAtThePrompt() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    send(.init(state: .working, app: "codex"), to: tab.focusedSessionID, in: harness)

    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID, agentID: "claude")
    )

    #expect(harness.model.agentIDAtThePrompt(of: tab) == AgentCatalogue.codexID)
  }

  @Test func aQuickCommandsDoneRaisesNoBannerWhereAnAgentsDoes() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let id = harness.openBackgroundTab().focusedSessionID

    send(.init(state: .working, app: "terraform"), to: id, in: harness)
    send(.init(state: .done, app: "terraform"), to: id, in: harness)
    #expect(harness.notifier.posted.isEmpty)

    send(.init(state: .working, app: "claude-code"), to: id, in: harness)
    send(.init(state: .done, app: "claude-code"), to: id, in: harness)
    #expect(harness.notifier.posted.count == 1)
  }

  @Test func aPaneThatBecomesAnAgentsAsItAsksIsCountedOnTheDock() {
    let (harness, session) = Harness.withOnePane()
    harness.model.showAgentBoard()
    harness.platform.badges.removeAll()

    send(.init(state: .blocked, app: "claude-code"), to: session.id, in: harness, from: nil)

    #expect(harness.platform.badges.last == 1)
  }

  @Test func aCommandsUnwordedQuestionIsNotWordedAsAnAgents() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()

    send(
      .init(state: .blocked, blockedReason: .question, app: "terraform"),
      to: tab.focusedSessionID,
      in: harness,
    )

    #expect(harness.notifier.posted.count == 1)
    #expect(harness.notifier.posted.first?.body != "An agent needs your input")
  }

  @Test func theProgramsClearAtItsExitTakesItsAgentOffThePrompt() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    send(.init(state: .idle, app: "claude-code"), to: tab.focusedSessionID, in: harness)

    send(.init(state: .clear), to: tab.focusedSessionID, in: harness)

    #expect(harness.model.agentIDAtThePrompt(of: tab) == nil)
  }

  @Test func theNextAgentAfterAProgramsClearIsNotHandedTheLastOnesDirectory() {
    let harness = Harness()
    let id = harness.openBackgroundTab().focusedSessionID
    harness.messageSource.send(
      SessionStateReport(
        state: .idle,
        sessionID: id,
        workingDirectory: "/tmp/a",
        agentID: "claude",
      )
    )
    send(.init(state: .idle, app: "claude-code"), to: id, in: harness, from: nil)
    send(.init(state: .clear), to: id, in: harness, from: nil)

    send(.init(state: .working, app: "claude-code"), to: id, in: harness, from: nil)

    let pasted = harness.model.pastedText(for: [URL(filePath: "/tmp/a/notes.txt")], into: id)
    #expect(pasted?.contains("/tmp/a/notes.txt") == true)
  }

  @Test func aNestedAgentsHookLeavesTheHoldingAgentsDirectoryForDrops() {
    let harness = Harness()
    let id = harness.openBackgroundTab().focusedSessionID
    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        workingDirectory: "/tmp/a",
        agentID: "claude",
      )
    )
    send(.init(state: .working, app: "claude-code"), to: id, in: harness, from: nil)

    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        workingDirectory: "/tmp/b",
        agentID: "codex",
      )
    )

    let pasted = harness.model.pastedText(for: [URL(filePath: "/tmp/a/notes.txt")], into: id)
    #expect(pasted == "@notes.txt")
  }

  @Test func aReportNamingNoAppKeepsTheHooksAgentWhileTheProgramHolds() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    let id = tab.focusedSessionID
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: id, agentID: "claude")
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: id, isFromShellIntegration: true)
    )
    send(.init(state: .working, app: "claude-code"), to: id, in: harness, from: nil)

    send(.init(state: .idle), to: id, in: harness, from: nil)

    #expect(harness.model.agentIDAtThePrompt(of: tab) == AgentCatalogue.claudeID)
  }

  @Test func thePollEndingAWrappedAgentsHoldTakesItsDirectoryWithIt() {
    let harness = Harness()
    let id = harness.openBackgroundTab().focusedSessionID
    harness.messageSource.send(
      SessionStateReport(
        state: .idle,
        sessionID: id,
        workingDirectory: "/tmp/a",
        agentID: "claude",
      )
    )
    send(.init(state: .working, app: "claude-code"), to: id, in: harness, from: deadPID())

    harness.model.sweepGonePIDs()

    #expect(harness.model.reportedAgents[id] == nil)
    #expect(harness.model.reportedAgentDirectories[id] == nil)
  }

  @Test func theLastWorkerOutRaisesTheBannerWithTheProgramsOwnWords() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let id = harness.openBackgroundTab().focusedSessionID
    send(.init(state: .working, app: "codex"), to: id, in: harness, from: nil)
    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        worker: WorkerReport(id: "w1", phase: .started),
      )
    )
    send(
      .init(state: .done, app: "codex", message: "Implemented X"),
      to: id,
      in: harness,
      from: nil,
    )

    harness.messageSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        worker: WorkerReport(id: "w1", phase: .ended),
      )
    )

    #expect(harness.notifier.posted.map(\.body) == ["Implemented X"])
  }
}
