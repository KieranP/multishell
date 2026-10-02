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
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()

    h.stateSource.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID))
    #expect(h.model.state(of: first) == .running)
    #expect(h.model.state(ofWorktree: h.main.id) == .running)
    #expect(h.model.workingAgentCount == 1)

    h.stateSource.send(SessionStateReport(state: .attention, sessionID: first.focusedSessionID))
    h.model.activate(first)
    #expect(h.model.state(of: first) == .attention, "looking is not answering")

    h.stateSource.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(h.model.state(of: first) == nil, "done for the shown tab has been seen")
  }

  @Test func aPlainCommandRunningIsNoAgentStillWorking() {
    let h = Harness()
    h.model.select(h.main)
    let id = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: id, command: "make", isFromShellIntegration: true))
    #expect(h.model.state(ofPane: id) == .running)
    #expect(h.model.workingAgentCount == 0)

    h.stateSource.send(SessionStateReport(state: .running, sessionID: id, agentID: "claude"))
    #expect(h.model.workingAgentCount == 1)
  }

  @Test func anAgentTypedAtThePromptWithNoHooksCountsAsWorking() {
    let h = Harness()
    h.model.select(h.main)
    let id = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: id, command: "codex", isFromShellIntegration: true))
    #expect(h.model.workingAgentCount == 1)
  }

  @Test func reportsAboutUnknownOrColdSessionsAreDropped() {
    let h = Harness()
    h.store.openTab(in: h.feature.id)
    let cold = h.model.workspace.sessions(in: h.feature.id)[0]
    h.model.select(h.main)

    h.stateSource.send(
      SessionStateReport(state: .running, sessionID: UUID(), cwd: h.main.path.path))
    h.stateSource.send(
      SessionStateReport(state: .running, sessionID: cold.id, cwd: h.main.path.path))

    #expect(h.model.sessionStates.showsNothing, "an id the app cannot place is not matched by cwd")
  }

  @Test func aReportWithOnlyADirectoryMarksTheWorktree() {
    let h = Harness()
    h.model.select(h.main)

    h.stateSource.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
    #expect(h.model.state(ofWorktree: h.main.id) == nil)
    h.stateSource.send(SessionStateReport(state: .done, cwd: h.feature.path.path + "/"))
    #expect(h.model.state(ofWorktree: h.feature.id) == .done)

    h.model.select(h.feature)
    #expect(h.model.state(ofWorktree: h.feature.id) == nil, "selecting the worktree is seeing it")

    h.stateSource.send(SessionStateReport(state: .running, cwd: "/nowhere/at/all"))
    #expect(h.model.sessionStates.showsNothing)
  }

  /// Claude Code started outside the app in a package directory reports that directory. The
  /// harness nests `feature` inside `main`, so the deeper one must win.
  @Test func aReportFromInsideAWorktreeMarksTheWorktreeContainingIt() {
    let h = Harness()
    h.model.select(h.main)

    h.stateSource.send(
      SessionStateReport(
        state: .attention, cwd: h.feature.path.appendingPathComponent("packages/api").path))
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
    #expect(h.model.state(ofWorktree: h.main.id) == nil, "the deepest worktree, not the first")

    h.stateSource.send(
      SessionStateReport(state: .failed, cwd: h.main.path.appendingPathComponent("featurette").path)
    )
    #expect(h.model.state(ofWorktree: h.main.id) == .failed, "a sibling by name is not inside")
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
  }

  /// `multishell state` typed at a prompt in one of our own tabs walks up
  /// to the app itself. A claim about our own pid would never clear.
  @Test func aReportNamingTheAppsOwnPidIsTakenAsNamingNone() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let me = ProcessInfo.processInfo.processIdentifier

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: tab.focusedSessionID, pid: me, agentID: AgentCatalogue.claudeID)
    )

    #expect(h.model.state(of: tab) == .running)
    #expect(h.model.sessionStates.trackedPIDs.isEmpty, "the app is not what is working")
    #expect(h.model.reportedAgents[tab.focusedSessionID]?.agentID == AgentCatalogue.claudeID)
    #expect(h.model.reportedAgents[tab.focusedSessionID]?.pid == nil)
  }

  /// A banner arrives with the app off screen, so it must name the worktree
  /// the way the sidebar the user is picturing does.
  @Test func aRenamedWorktreeIsNamedByItsNameInABanner() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")

    h.stateSource.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))

    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.posted.first?.title.contains("Checkout flow") == true)
    #expect(h.notifier.posted.first?.title.contains("feature") == false, "not the branch")
  }

  /// The banner already up is the prompt's, and posting again under the same key would
  /// replace it with a body that says less.
  @Test func aWorkerTickRaisesNoSecondBannerForAPromptAlreadyUp() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session,
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    h.stateSource.send(
      SessionStateReport(state: .attention, sessionID: session, message: "Needs Bash"))
    #expect(h.notifier.posted.count == 1)

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, subagent: SubagentReport(id: "w1", phase: .ended)))

    #expect(h.notifier.posted.count == 1, "the prompt's banner is the only one")
    #expect(h.notifier.posted.first?.body == "Needs Bash")
    #expect(h.notifier.withdrawn.isEmpty, "and it was not taken back either")
  }

  /// The chip on the pane's row and on its card read the same roster: a Done on
  /// screen gives way to a worker, and the last one out posts the Done banner.
  @Test func workersShowOnTheRowAndTheCardAndKeepTheWorktreeWorking() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    h.stateSource.send(SessionStateReport(state: .running, sessionID: session, agentID: "claude"))
    h.stateSource.send(SessionStateReport(state: .done, sessionID: session, agentID: "claude"))
    #expect(h.model.state(ofWorktree: h.main.id) == .done)
    #expect(h.notifier.posted.count == 1)

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    h.stateSource.send(
      SessionStateReport(
        state: .running, cwd: h.main.path.path, agentID: "claude",
        subagent: SubagentReport(id: "w2", type: "Plan", phase: .working)))

    #expect(h.model.state(ofWorktree: h.main.id) == .running, "a worker out is work")
    #expect(h.model.subagents(ofPane: session).map(\.id) == ["w1"], "the pane's own only")
    #expect(
      h.model.subagents(ofPane: h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)
        .isEmpty)
    #expect(h.model.state(ofPane: session) == .running)
    let card = h.model.agentBoardCards.first { $0.id == session }
    #expect(card?.subagents.map(\.type) == ["Explore"], "a card has its own pane's only")
    #expect(card?.subagents.first?.since != nil, "stamped by the model's clock")

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: session, agentID: "claude",
        subagent: SubagentReport(id: "w1", phase: .ended)))
    h.stateSource.send(
      SessionStateReport(
        state: .running, cwd: h.main.path.path, agentID: "claude",
        subagent: SubagentReport(id: "w2", phase: .ended)))
    #expect(h.model.subagents(ofPane: session).isEmpty)
    #expect(h.model.state(ofWorktree: h.main.id) == .done, "the displaced Done comes back")
    #expect(h.notifier.posted.count == 2, "and is announced once")
  }

  @Test func launchingAnAgentFlashesThenIdlesUntilAPromptDrivesItsOwnStates() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()  // background it
    let id = tab.focusedSessionID

    // The shell hook fires as `claude` starts: a command is running.
    h.stateSource.send(SessionStateReport(state: .running, sessionID: id))
    #expect(h.model.state(of: tab) == .running)

    // Claude's SessionStart hook: it is up and waiting for a prompt, not
    // working. Back to grey.
    h.stateSource.send(SessionStateReport(state: .idle, sessionID: id))
    #expect(h.model.state(of: tab) == nil, "an agent at its prompt is idle")

    // A prompt: working again (UserPromptSubmit / PreToolUse).
    h.stateSource.send(SessionStateReport(state: .running, sessionID: id))
    #expect(h.model.state(of: tab) == .running)

    h.stateSource.send(SessionStateReport(state: .attention, sessionID: id, message: "Needs Bash"))
    #expect(h.model.state(of: tab) == .attention)

    h.stateSource.send(SessionStateReport(state: .done, sessionID: id))
    #expect(h.model.state(of: tab) == .done)
  }

  @Test func anAgentsSessionStartClearsTheShellsOwnWorking() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let id = tab.focusedSessionID

    h.stateSource.send(
      SessionStateReport(
        state: .running, sessionID: id, pid: 4242, command: "claude", isFromShellIntegration: true))
    h.stateSource.send(SessionStateReport(state: .idle, sessionID: id, startsSession: true))

    #expect(h.model.state(of: tab) == nil)
  }

  @Test func reportsOverARealSocketReachTheModel() async throws {
    let path = URL(fileURLWithPath: "/tmp/ms-model-\(UUID().uuidString.prefix(8)).sock")
    let source = SocketStateSource(path: path)
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
    let tmp = try Scratch.directory("socket")
    defer { Scratch.remove(tmp) }
    let store = WorkspaceStore(
      file: WorkspaceFile(fileURL: tmp.appendingPathComponent("state.json")))
    let project = store.addProject(at: tmp)
    let main = Worktree(
      path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([main], forProject: project.id)
    let engine = FakeEngine()
    let model = AppModel(
      store: store, host: engine, coordinator: nil,
      watcher: FakeWatcher(), stateSource: source)
    _ = model.startStateSource()
    model.select(main)
    let tab = model.workspace.activeTab(in: main.id)!
    model.newTab()

    let report = SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    try UnixSocketClient.send(try report.encodedLine(), to: path)
    try UnixSocketClient.send("this is not a report\n", to: path)

    try await waitUntil { model.state(of: tab) != nil }
    #expect(model.state(of: tab) == .attention)
  }
}
