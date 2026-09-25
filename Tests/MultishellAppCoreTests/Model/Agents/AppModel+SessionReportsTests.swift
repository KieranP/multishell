import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Reports arriving at the model: which tab they land on, what they clear,
/// when a notification is posted, and how a dead agent is noticed.
@Suite @MainActor
struct AppModelSessionReportsTests {
  @Test func aReportAboutALiveSessionColoursItsTabAndWorktree() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()

    h.source.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID))
    #expect(h.model.state(of: first) == .running)
    #expect(h.model.state(ofWorktree: h.main.id) == .running)
    #expect(h.model.workingAgentCount == 1)

    h.source.send(SessionStateReport(state: .attention, sessionID: first.focusedSessionID))
    h.model.activate(first)
    #expect(h.model.state(of: first) == .attention, "looking is not answering")

    h.source.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(h.model.state(of: first) == nil, "done for the shown tab has been seen")
  }

  @Test func aPlainCommandRunningIsNoAgentStillWorking() {
    let h = Harness()
    h.model.select(h.main)
    let id = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.source.send(
      SessionStateReport(state: .running, sessionID: id, command: "make", isShell: true))
    #expect(h.model.state(ofPane: id) == .running)
    #expect(h.model.workingAgentCount == 0)

    h.source.send(SessionStateReport(state: .running, sessionID: id, agent: "claude"))
    #expect(h.model.workingAgentCount == 1)
  }

  @Test func anAgentTypedAtThePromptWithNoHooksCountsAsWorking() {
    let h = Harness()
    h.model.select(h.main)
    let id = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.source.send(
      SessionStateReport(state: .running, sessionID: id, command: "codex", isShell: true))
    #expect(h.model.workingAgentCount == 1)
  }

  @Test func reportsAboutUnknownOrColdSessionsAreDropped() {
    let h = Harness()
    h.store.openTab(in: h.feature.id)
    let cold = h.model.workspace.sessions(in: h.feature.id)[0]
    h.model.select(h.main)

    h.source.send(SessionStateReport(state: .running, sessionID: UUID(), cwd: h.main.path.path))
    h.source.send(SessionStateReport(state: .running, sessionID: cold.id, cwd: h.main.path.path))

    #expect(h.model.sessionStates.isEmpty, "an id the app cannot place is not matched by cwd")
  }

  @Test func aReportWithOnlyADirectoryMarksTheWorktree() {
    let h = Harness()
    h.model.select(h.main)

    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
    #expect(h.model.state(ofWorktree: h.main.id) == nil)
    h.source.send(SessionStateReport(state: .done, cwd: h.feature.path.path + "/"))
    #expect(h.model.state(ofWorktree: h.feature.id) == .done)

    h.model.select(h.feature)
    #expect(h.model.state(ofWorktree: h.feature.id) == nil, "selecting the worktree is seeing it")

    h.source.send(SessionStateReport(state: .running, cwd: "/nowhere/at/all"))
    #expect(h.model.sessionStates.isEmpty)
  }

  /// Claude Code started outside the app in a package directory reports that directory. The
  /// harness nests `feature` inside `main`, so the deeper one must win.
  @Test func aReportFromInsideAWorktreeMarksTheWorktreeContainingIt() {
    let h = Harness()
    h.model.select(h.main)

    h.source.send(
      SessionStateReport(
        state: .attention, cwd: h.feature.path.appendingPathComponent("packages/api").path))
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
    #expect(h.model.state(ofWorktree: h.main.id) == nil, "the deepest worktree, not the first")

    h.source.send(
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

    h.source.send(
      SessionStateReport(
        state: .running, sessionID: tab.focusedSessionID, pid: me, agent: AgentCatalogue.claudeID))

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

    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))

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
    h.source.send(
      SessionStateReport(
        state: .running, sessionID: session,
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    h.source.send(
      SessionStateReport(state: .attention, sessionID: session, message: "Needs Bash"))
    #expect(h.notifier.posted.count == 1)

    h.source.send(
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
    h.source.send(SessionStateReport(state: .running, sessionID: session, agent: "claude"))
    h.source.send(SessionStateReport(state: .done, sessionID: session, agent: "claude"))
    #expect(h.model.state(ofWorktree: h.main.id) == .done)
    #expect(h.notifier.posted.count == 1)

    h.source.send(
      SessionStateReport(
        state: .running, sessionID: session, agent: "claude",
        subagent: SubagentReport(id: "w1", type: "Explore", phase: .started)))
    h.source.send(
      SessionStateReport(
        state: .running, cwd: h.main.path.path, agent: "claude",
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

    h.source.send(
      SessionStateReport(
        state: .running, sessionID: session, agent: "claude",
        subagent: SubagentReport(id: "w1", phase: .ended)))
    h.source.send(
      SessionStateReport(
        state: .running, cwd: h.main.path.path, agent: "claude",
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
    h.source.send(SessionStateReport(state: .running, sessionID: id))
    #expect(h.model.state(of: tab) == .running)

    // Claude's SessionStart hook: it is up and waiting for a prompt, not
    // working. Back to grey.
    h.source.send(SessionStateReport(state: .idle, sessionID: id))
    #expect(h.model.state(of: tab) == nil, "an agent at its prompt is idle")

    // A prompt: working again (UserPromptSubmit / PreToolUse).
    h.source.send(SessionStateReport(state: .running, sessionID: id))
    #expect(h.model.state(of: tab) == .running)

    // A permission prompt: waiting.
    h.source.send(SessionStateReport(state: .attention, sessionID: id, message: "Needs Bash"))
    #expect(h.model.state(of: tab) == .attention)

    // The turn ends: done.
    h.source.send(SessionStateReport(state: .done, sessionID: id))
    #expect(h.model.state(of: tab) == .done)
  }

  @Test func anAgentsSessionStartClearsTheShellsOwnWorking() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let id = tab.focusedSessionID

    h.source.send(
      SessionStateReport(
        state: .running, sessionID: id, pid: 4242, command: "claude", isShell: true))
    h.source.send(SessionStateReport(state: .idle, sessionID: id, startsSession: true))

    #expect(h.model.state(of: tab) == nil)
  }

  @Test func aReportedProcessThatExitsClearsWorking() async throws {
    let h = Harness()
    h.model.pidPollInterval = .milliseconds(50)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    // A child that is gone by the time the poll looks.
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sh")
    child.arguments = ["-c", "exit 0"]
    try child.run()
    child.waitUntilExit()
    let gone = child.processIdentifier

    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: gone))
    #expect(h.model.state(of: tab) == .running)
    #expect(h.model.pidWatch != nil)

    try await waitUntil({ h.model.state(of: tab) == nil }, seconds: 4)
    #expect(h.model.state(of: tab) == nil, "the agent was killed without a Stop hook")
    #expect(h.model.pidWatch == nil, "nothing left to watch")

    // A live process keeps its state.
    h.source.send(
      SessionStateReport(
        state: .running, sessionID: tab.focusedSessionID,
        pid: ProcessInfo.processInfo.processIdentifier))
    try await Task.sleep(for: .milliseconds(200))
    #expect(h.model.state(of: tab) == .running)
  }

  @Test func aStopHeldForABackgroundShellIsPaidAndAnnouncedWhenTheShellExits() async throws {
    let h = Harness()
    h.model.pidPollInterval = .milliseconds(50)
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier

    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", "read line"]
    let input = Pipe()
    shell.standardInput = input
    try shell.run()
    defer { shell.terminate() }

    h.source.send(SessionStateReport(state: .running, sessionID: session, pid: me, agent: "claude"))
    h.source.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agent: "claude",
        backgroundShells: [shell.processIdentifier]))
    #expect(h.model.state(ofPane: session) == .running, "the shell is still working")
    #expect(h.model.subagents(ofPane: session).count == 1)
    #expect(h.notifier.posted.isEmpty)

    try input.fileHandleForWriting.close()
    shell.waitUntilExit()
    try await waitUntil({ h.model.state(ofPane: session) == .done }, seconds: 4)
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.model.subagents(ofPane: session).isEmpty)
    #expect(h.notifier.posted.count == 1, "the Done announced once, at the end")
  }

  private func exitedProcess() throws -> Int32 {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sh")
    child.arguments = ["-c", "exit 0"]
    try child.run()
    child.waitUntilExit()
    return child.processIdentifier
  }

  @Test func aResumeThatComesInTimeIsTheOnlyDoneAnnounced() async throws {
    let h = Harness()
    h.model.resumeGrace = .milliseconds(100)
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = try exitedProcess()

    h.source.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agent: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    h.model.sweepGonePIDs()
    #expect(h.model.state(ofPane: session) == .running, "waiting on the turn the exit starts")

    h.source.send(SessionStateReport(state: .running, sessionID: session, agent: "claude"))
    h.source.send(
      SessionStateReport(
        state: .done, sessionID: session, agent: "claude", resumesAfterWorkers: true))
    try await Task.sleep(for: .milliseconds(400))
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }

  @Test func aResumeThatNeverComesIsPaidAndAnnouncedWhenOverdue() async throws {
    let h = Harness()
    h.model.resumeGrace = .milliseconds(100)
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    let me = ProcessInfo.processInfo.processIdentifier
    let shell = try exitedProcess()

    h.source.send(
      SessionStateReport(
        state: .done, sessionID: session, pid: me, agent: "claude", backgroundShells: [shell],
        resumesAfterWorkers: true))
    h.model.sweepGonePIDs()
    #expect(h.notifier.posted.isEmpty)
    try await waitUntil({ h.model.state(ofPane: session) == .done }, seconds: 2)
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }

  /// Whether the agent or its shell is checked first is a set's order, so
  /// several pairs make sure both orders are met.
  @Test func anAgentDyingWithItsShellAnnouncesNothingWhicheverIsSweptFirst() throws {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let session = tab.focusedSessionID
    for _ in 0..<12 {
      let agent = try exitedProcess()
      let shell = try exitedProcess()
      h.source.send(SessionStateReport(state: .running, sessionID: session, pid: agent))
      h.source.send(
        SessionStateReport(
          state: .done, sessionID: session, pid: agent, backgroundShells: [shell]))
      h.model.sweepGonePIDs()
      #expect(h.model.state(ofPane: session) == nil, "agent \(agent), shell \(shell)")
    }
    #expect(h.notifier.posted.isEmpty)
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
