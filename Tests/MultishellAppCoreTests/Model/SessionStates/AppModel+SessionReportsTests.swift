import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Reports arriving at the model: which tab they land on, what they clear,
/// and when a notification is posted.
@Suite @MainActor
struct AppModelSessionReportsTests {
  @Test func aReportAboutALiveSessionColoursItsTabAndWorktree() {
    let harness = Harness()
    let first = harness.openBackgroundTab()

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: first.focusedSessionID)
    )
    #expect(harness.model.state(of: first) == .running)
    #expect(harness.model.state(ofWorktree: harness.main.id) == .running)
    #expect(harness.model.workingAgentCount == 1)

    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: first.focusedSessionID)
    )
    harness.model.activate(first)
    #expect(harness.model.state(of: first) == .attention, "looking is not answering")

    harness.stateSource.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(harness.model.state(of: first) == nil, "done for the shown tab has been seen")
  }

  @Test func aPlainCommandRunningIsNoAgentStillWorking() {
    let harness = Harness()
    harness.model.select(harness.main)
    let id = harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        command: "make",
        isFromShellIntegration: true,
      )
    )
    #expect(harness.model.state(ofPane: id) == .running)
    #expect(harness.model.workingAgentCount == 0)

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: id, agentID: "claude"))
    #expect(harness.model.workingAgentCount == 1)
  }

  @Test func anAgentTypedAtThePromptWithNoHooksCountsAsWorking() {
    let harness = Harness()
    harness.model.select(harness.main)
    let id = harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        command: "codex",
        isFromShellIntegration: true,
      )
    )
    #expect(harness.model.workingAgentCount == 1)
  }

  @Test func reportsAboutUnknownOrColdSessionsAreDropped() {
    let harness = Harness()
    harness.store.openTab(in: harness.feature.id)
    let cold = harness.model.workspace.sessions(in: harness.feature.id)[0]
    harness.model.select(harness.main)

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: UUID(),
        workingDirectory: harness.main.path.path,
      )
    )
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: cold.id,
        workingDirectory: harness.main.path.path,
      )
    )

    #expect(
      harness.model.sessionStates.showsNothing,
      "an id the app cannot place is not matched by cwd",
    )
  }

  @Test func aReportWithOnlyADirectoryMarksTheWorktree() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.stateSource.send(
      SessionStateReport(state: .attention, workingDirectory: harness.feature.path.path)
    )
    #expect(harness.model.state(ofWorktree: harness.feature.id) == .attention)
    #expect(harness.model.state(ofWorktree: harness.main.id) == nil)
    harness.stateSource.send(
      SessionStateReport(state: .done, workingDirectory: harness.feature.path.path + "/")
    )
    #expect(harness.model.state(ofWorktree: harness.feature.id) == .done)

    harness.model.select(harness.feature)
    #expect(
      harness.model.state(ofWorktree: harness.feature.id) == nil,
      "selecting the worktree is seeing it",
    )

    harness.stateSource.send(
      SessionStateReport(state: .running, workingDirectory: "/nowhere/at/all")
    )
    #expect(harness.model.sessionStates.showsNothing)
  }

  /// Claude Code started outside the app in a package directory reports that directory. The
  /// harness nests `feature` inside `main`, so the deeper one must win.
  @Test func aReportFromInsideAWorktreeMarksTheWorktreeContainingIt() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.stateSource.send(
      SessionStateReport(
        state: .attention,
        workingDirectory: harness.feature.path.appendingPathComponent("packages/api").path,
      )
    )
    #expect(harness.model.state(ofWorktree: harness.feature.id) == .attention)
    #expect(
      harness.model.state(ofWorktree: harness.main.id) == nil,
      "the deepest worktree, not the first",
    )

    harness.stateSource.send(
      SessionStateReport(
        state: .failed,
        workingDirectory: harness.main.path.appendingPathComponent("featurette").path,
      )
    )
    #expect(
      harness.model.state(ofWorktree: harness.main.id) == .failed,
      "a sibling by name is not inside",
    )
    #expect(harness.model.state(ofWorktree: harness.feature.id) == .attention)
  }

  /// `multishell state` typed at a prompt in one of our own tabs walks up
  /// to the app itself. A claim about our own pid would never clear.
  @Test func aReportNamingTheAppsOwnPidIsTakenAsNamingNone() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let ownPID = ProcessInfo.processInfo.processIdentifier

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: tab.focusedSessionID,
        pid: ownPID,
        agentID: AgentCatalogue.claudeID,
      )
    )

    #expect(harness.model.state(of: tab) == .running)
    #expect(harness.model.sessionStates.trackedPIDs.isEmpty, "the app is not what is working")
    #expect(harness.model.reportedAgents[tab.focusedSessionID]?.agentID == AgentCatalogue.claudeID)
    #expect(harness.model.reportedAgents[tab.focusedSessionID]?.pid == nil)
  }

  /// A banner arrives with the app off screen, so it must name the worktree
  /// the way the sidebar the user is picturing does.
  @Test func aRenamedWorktreeIsNamedByItsNameInABanner() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    harness.model.renameWorktree(harness.feature.id, to: "Checkout flow")

    harness.stateSource.send(
      SessionStateReport(state: .attention, workingDirectory: harness.feature.path.path)
    )

    #expect(harness.notifier.posted.count == 1)
    #expect(harness.notifier.posted.first?.title.contains("Checkout flow") == true)
    #expect(harness.notifier.posted.first?.title.contains("feature") == false, "not the branch")
  }

  /// The banner already up is the prompt's, and posting again under the same key would
  /// replace it with a body that says less.
  @Test func aWorkerTickRaisesNoSecondBannerForAPromptAlreadyUp() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        worker: WorkerReport(id: "w1", phase: .started, type: "Explore"),
      )
    )
    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: session, message: "Needs Bash")
    )
    #expect(harness.notifier.posted.count == 1)

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        worker: WorkerReport(id: "w1", phase: .ended),
      )
    )

    #expect(harness.notifier.posted.count == 1, "the prompt's banner is the only one")
    #expect(harness.notifier.posted.first?.body == "Needs Bash")
    #expect(harness.notifier.withdrawn.isEmpty, "and it was not taken back either")
  }

  /// The chip on the pane's row and on its card read the same roster: a Done on
  /// screen gives way to a worker, and the last one out posts the Done banner.
  @Test func workersShowOnTheRowAndTheCardAndKeepTheWorktreeWorking() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    let tab = harness.openBackgroundTab()
    let session = tab.focusedSessionID
    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session, agentID: "claude")
    )
    harness.stateSource.send(
      SessionStateReport(state: .done, sessionID: session, agentID: "claude")
    )
    #expect(harness.model.state(ofWorktree: harness.main.id) == .done)
    #expect(harness.notifier.posted.count == 1)

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .started, type: "Explore"),
      )
    )
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        workingDirectory: harness.main.path.path,
        agentID: "claude",
        worker: WorkerReport(id: "w2", phase: .working, type: "Plan"),
      )
    )

    #expect(harness.model.state(ofWorktree: harness.main.id) == .running, "a worker out is work")
    #expect(harness.model.workers(ofPane: session).map(\.id) == ["w1"], "the pane's own only")
    #expect(
      harness.model.workers(
        ofPane: harness.model.workspace.activeTab(in: harness.main.id)!.focusedSessionID
      )
      .isEmpty
    )
    #expect(harness.model.state(ofPane: session) == .running)
    let card = harness.model.agentBoardCards.first { $0.id == session }
    #expect(card?.workers.map(\.type) == ["Explore"], "a card has its own pane's only")
    #expect(card?.workers.first?.startedAt != nil, "stamped by the model's clock")

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: session,
        agentID: "claude",
        worker: WorkerReport(id: "w1", phase: .ended),
      )
    )
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        workingDirectory: harness.main.path.path,
        agentID: "claude",
        worker: WorkerReport(id: "w2", phase: .ended),
      )
    )
    #expect(harness.model.workers(ofPane: session).isEmpty)
    #expect(
      harness.model.state(ofWorktree: harness.main.id) == .done,
      "the displaced Done comes back",
    )
    #expect(harness.notifier.posted.count == 2, "and is announced once")
  }

  @Test func launchingAnAgentFlashesThenIdlesUntilAPromptDrivesItsOwnStates() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    let id = tab.focusedSessionID

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: id))
    #expect(harness.model.state(of: tab) == .running, "the shell hook as `claude` starts")

    harness.stateSource.send(SessionStateReport(state: .idle, sessionID: id))
    #expect(harness.model.state(of: tab) == nil, "SessionStart: an agent at its prompt is idle")

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: id))
    #expect(harness.model.state(of: tab) == .running, "UserPromptSubmit or PreToolUse")

    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: id, message: "Needs Bash")
    )
    #expect(harness.model.state(of: tab) == .attention)

    harness.stateSource.send(SessionStateReport(state: .done, sessionID: id))
    #expect(harness.model.state(of: tab) == .done)
  }

  @Test func anAgentsSessionStartClearsTheShellsOwnWorking() {
    let harness = Harness()
    let tab = harness.openBackgroundTab()
    let id = tab.focusedSessionID

    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: id,
        pid: 4242,
        command: "claude",
        isFromShellIntegration: true,
      )
    )
    harness.stateSource.send(SessionStateReport(state: .idle, sessionID: id, startsSession: true))

    #expect(harness.model.state(of: tab) == nil)
  }

  @Test func reportsOverARealSocketReachTheModel() async throws {
    let path = Scratch.socketPath("model")
    let source = SocketStateSource(path: path)
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
    let harness = Harness(socketSource: source)
    let model = harness.model
    _ = model.startStateSource()
    let tab = harness.openBackgroundTab()

    let report = SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    try UnixSocketClient.send(try report.encodedLine(), to: path)
    try UnixSocketClient.send("this is not a report\n", to: path)

    try await waitUntil { model.state(of: tab) != nil }
    #expect(model.state(of: tab) == .attention)
  }
}
