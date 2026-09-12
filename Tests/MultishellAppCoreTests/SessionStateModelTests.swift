import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

/// Reports arriving at the model: which tab they land on, what they clear,
/// when a notification is posted, and how a dead agent is noticed.
@Suite @MainActor
struct SessionStateModelTests {
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

  /// A banner arrives with the app off screen, so it must name the worktree
  /// the way the sidebar the user is picturing does.
  @Test func aRenamedWorktreeIsNamedByItsNameInABanner() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")

    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))

    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.posted.first?.title.contains("Checkout flow") == true)
    #expect(h.notifier.posted.first?.title.contains("feature") == false, "not the branch")
  }

  @Test func notificationsFollowThePreferenceAndTheShownTab() {
    let h = Harness()
    h.source.send(SessionStateReport(state: .attention, cwd: h.main.path.path))
    #expect(h.notifier.posted.isEmpty, "off until turned on")
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()

    h.source.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.isEmpty, "working is never a banner")

    h.source.send(
      SessionStateReport(
        state: .attention, sessionID: first.focusedSessionID, message: "Needs Bash"))
    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.posted.first?.body == "Needs Bash")
    #expect(h.notifier.posted.first?.title.contains("main") == true)
    #expect(h.notifier.posted.first?.key == .session(first.focusedSessionID))

    h.model.setNotifications(NotificationPreference(attention: true))
    h.source.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.count == 1)

    h.model.setNotifications(.off)
    h.source.send(SessionStateReport(state: .attention, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.count == 1)

    // A click on the banner brings the tab back.
    h.notifier.onActivate?(.session(first.focusedSessionID))
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == first.id)
  }

  /// The user answers the question in the pane and the agent gets back to
  /// work: the banner is about something that has stopped being true, so it
  /// goes rather than sitting in Notification Centre until it is swiped.
  @Test func aBannerIsTakenBackWhenTheStateItNamedMovesOn() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.withdrawn.isEmpty, "nothing has changed yet")

    h.source.send(SessionStateReport(state: .running, sessionID: session))
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.notifier.posted.count == 1, "working raises none of its own")

    h.source.send(SessionStateReport(state: .running, sessionID: session))
    #expect(h.notifier.withdrawn.count == 1, "taken back once, not on every report after")
  }

  /// Looking at the pane answers the banner even where it does not answer
  /// the question: Waiting survives being seen, and its dot stays blue,
  /// but the interruption has done its job.
  @Test func lookingAtThePaneTakesItsBannerBackAndLeavesTheDot() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(h.notifier.posted.count == 1)

    h.model.activate(tab)
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.model.sessionStates[.session(session)] == .attention, "the question still stands")
  }

  /// The pane on screen while the user is in another app has not been seen,
  /// and the dot and the banner have to agree about that or the one says
  /// there is nothing to look at while the other is still saying there is.
  /// A shell exiting anywhere runs the seen-it pass, so being away has to
  /// hold both of them.
  @Test func nothingCountsAsSeenWhileTheUserIsInAnotherApp() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID

    h.platform.isActive = false
    h.source.send(SessionStateReport(state: .done, sessionID: session))
    #expect(h.notifier.posted.count == 1, "shown, but nobody is looking")
    #expect(h.model.sessionStates[.session(session)] == .done, "and the dot says so too")

    h.model.sync()
    #expect(h.notifier.withdrawn.isEmpty, "still away")
    #expect(h.model.sessionStates[.session(session)] == .done, "a shell exiting is not a look")

    h.platform.isActive = true
    h.platform.onDidBecomeActive?()
    #expect(h.notifier.withdrawn == [.session(session)], "back, and the pane is on screen")
    #expect(h.model.sessionStates[.session(session)] == nil, "seen now, so the dot goes as well")
  }

  /// A pane that is gone has nothing left to say, so its banner goes with
  /// it rather than sitting in Notification Centre pointing at a tab that
  /// cannot be opened.
  @Test func closingATabTakesItsBannerWithIt() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    let session = first.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .done, sessionID: session))
    #expect(h.notifier.posted.count == 1)

    h.model.closeTab(first.id)
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.model.notifiedKeys.isEmpty, "and nothing is left tracking it")
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

    for _ in 0..<80 where h.model.state(of: tab) != nil {
      try await Task.sleep(for: .milliseconds(50))
    }
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

  @Test func aFinishedCommandClearsWorkingAndCommandsAreDistinctFromActivity() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    h.source.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID, pid: 1))

    h.engine.delegate?.terminalHost(h.engine, didRetitle: first.focusedSessionID, to: "claude")
    #expect(h.model.state(of: first) == .running, "a title change is not evidence of an exit")

    h.engine.delegate?.terminalHost(
      h.engine, didFinishCommandIn: first.focusedSessionID, exitCode: 0)
    #expect(h.model.state(of: first) == .done)
    #expect(h.model.sessionStates.trackedPIDs.isEmpty)

    h.engine.delegate?.terminalHost(
      h.engine, didFinishCommandIn: first.focusedSessionID, exitCode: 1)
    #expect(h.model.state(of: first) == .error, "a failure is not covered by an unseen Done")
    #expect(h.model.state(ofWorktree: h.main.id) == .error)
    h.model.activate(first)
    #expect(h.model.state(of: first) == .error, "a look is not dealing with a failure")
    h.model.clearState(of: first)
    #expect(h.model.state(of: first) == nil, "the pane's own Clear Status is")
  }

  @Test func closingAWorkingPaneAsksFirstAndTheConfirmationCloses() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    h.model.closeActivePane()
    #expect(h.model.pendingClose == .pane(tab.focusedSessionID))
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "nothing closed yet")

    h.model.pendingClose = nil
    h.model.closeActiveTab()
    #expect(h.model.pendingClose == .tab(tab.id))

    h.model.confirmPendingClose()
    #expect(h.model.pendingClose == nil)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  /// The question goes when its subject does, whichever way that happens.
  /// A project removal is one way; this is the other, and it is why the
  /// prune lives in `sync` rather than beside a removal.
  @Test func aCloseWaitingOnAConfirmationGoesWithTheProjectItAskedAbout() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    h.model.closeActiveTab()
    #expect(h.model.pendingClose == .tab(tab.id))

    h.model.removeProject(h.project)
    #expect(h.model.pendingClose == nil, "nothing left to ask about")
  }

  @Test func clearingByHandDropsAStaleWorkingDot() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID, pid: 99999))
    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path, pid: 99998))

    h.model.clearState(of: tab)
    #expect(h.model.state(of: tab) == nil)
    h.model.clearState(ofWorktree: h.feature.id)
    #expect(h.model.sessionStates.isEmpty)
    #expect(h.model.pidWatch == nil)
  }

  @Test func reportsOverARealSocketReachTheModel() async throws {
    let path = URL(fileURLWithPath: "/tmp/ms-model-\(UUID().uuidString.prefix(8)).sock")
    let source = SocketStateSource(path: path)
    defer { source.stop() }
    let tmp = try Scratch.directory("socket")
    let store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: tmp.appendingPathComponent("state.json")))
    let project = store.addProject(at: tmp)
    let main = Worktree(
      path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([main], forProject: project.id)
    let engine = FakeEngine()
    let model = AppModel(
      store: store, host: MultiEngineHost(engine: .ghostty) { _ in engine }, worktrees: nil,
      watcher: FakeWatcher(), stateSource: source)
    model.startStateSource()
    model.select(main)
    let tab = model.workspace.activeTab(in: main.id)!
    model.newTab()

    let report = SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    try UnixSocketClient.send(try report.encodedLine(), to: path)
    try UnixSocketClient.send("this is not a report\n", to: path)

    for _ in 0..<160 where model.state(of: tab) == nil {
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(model.state(of: tab) == .attention)
  }
}

/// Agent tabs: the store keeps an id, the shell gets a command line.
@Suite @MainActor
struct AgentTabTests {
  @Test func newAgentTabRecordsTheIdAndOpensTheAgentThroughTheLoginShell() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)

    h.model.newAgentTab()

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = h.model.workspace.session(tab.focusedSessionID)!
    #expect(session.agentID == "claude")
    #expect(session.command == nil, "the store never holds the command line")
    #expect(h.model.title(of: tab) == "Claude Code")
    let opened = h.engine.opened.last!
    #expect(opened.id == session.id)
    #expect(opened.command?.last?.hasPrefix("claude; ") == true, "\(opened.command ?? [])")
    #expect(opened.command?.last?.contains("exec ") == true, "a shell takes over after the agent")
  }

  @Test func theProjectOverrideBeatsTheGlobalAndNoneMeansNoAgent() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    #expect(h.model.preferredAgentID(for: h.main) == "claude")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "codex"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == "codex")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.select(h.main)
    let tabs = h.model.workspace.tabs(in: h.main.id).count
    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == tabs)
    #expect(h.model.presentedError?.title == "No agent chosen")
  }

  @Test func aSavedAgentTabResumesWhereItCanAndIsAShellWhereItCannot() throws {
    let file = Scratch.path("agent-relaunch")
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    let before = Harness(stateFile: file)
    before.model.select(before.main)
    before.store.openTab(in: before.main.id, title: "Claude Code", agentID: "claude")
    before.store.openTab(in: before.main.id, title: "Aider", agentID: "aider")
    before.model.saveNow()

    let (store, _) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: MultiEngineHost(engine: .ghostty) { _ in engine }, worktrees: nil,
      watcher: FakeWatcher())
    after.select(before.main)

    let byTitle = Dictionary(
      uniqueKeysWithValues: engine.opened.map { (store.workspace.session($0.id)!.title, $0) })
    #expect(byTitle["Claude Code"]?.command?.last?.hasPrefix("claude --continue; ") == true)
    #expect(byTitle["Aider"]?.command == nil, "no resume flag, so a plain shell keeps the title")
    #expect(after.title(of: store.workspace.tabs(in: before.main.id)[2]) == "Aider")
  }

  @Test func anAgentThatIsNotInstalledOpensAShellAndSaysSoOnce() {
    let h = Harness()
    h.model.loginEnvironment = LoginShellEnvironment(
      variables: ["PATH": "/usr/bin"], source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    h.model.agentDetection = AgentDetection(path: "/usr/bin")
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)
    h.model.presentedError = nil

    h.model.newAgentTab()
    #expect(h.engine.opened.last?.command == nil)
    #expect(h.model.presentedError?.title == "Claude Code is not installed")

    h.model.presentedError = nil
    h.model.newAgentTab()
    #expect(h.model.presentedError == nil, "reported once per run")
    #expect(h.model.workspace.tabs(in: h.main.id).count == 3)
  }

  @Test func autoStartMakesNewTabAndTheFirstTabTheAgentButNeverASplit() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)

    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    #expect(
      h.model.workspace.session(first.focusedSessionID)?.agentID == "claude",
      "the first tab after select, which is what follows a create")
    #expect(h.model.title(of: first) == "Claude Code")

    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!
    #expect(h.model.workspace.session(second.focusedSessionID)?.agentID == "claude")

    h.model.splitActivePane(.horizontal)
    let split = h.model.workspace.tab(second.id)!
    let pane = split.sessionIDs.first { $0 != second.focusedSessionID }!
    #expect(h.model.workspace.session(pane)?.agentID == nil, "splits stay plain shells")

    h.model.newShellTab()
    let shell = h.model.workspace.activeTab(in: h.main.id)!
    #expect(
      h.model.workspace.session(shell.focusedSessionID)?.agentID == nil, "a shell stays reachable")
  }

  @Test func autoStartOffOrNoAgentOpensShellsAndTheProjectOverrideWins() {
    let h = Harness()
    h.model.setPreferredAgent("claude")
    h.model.select(h.main)
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "off by default")

    h.model.updateSettings(ProjectSettings(autoStartAgent: true), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == "claude", "the project override turns it on")

    h.model.setAutoStartAgent(true)
    h.model.updateSettings(ProjectSettings(autoStartAgent: false), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "the project override turns it off")

    h.model.updateSettings(ProjectSettings(preferredAgentID: "none"), for: h.project)
    h.model.newTab()
    #expect(
      h.model.workspace.session(h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID)?
        .agentID == nil, "auto-start with no agent in force is a shell")
  }

  @Test func theCustomEntryRunsWhatWasTyped() {
    let h = Harness()
    h.model.setPreferredAgent("custom")
    h.model.setCustomAgentCommand("my-agent --fast")
    h.model.select(h.main)
    h.model.newAgentTab()
    #expect(h.engine.opened.last?.command?.last?.hasPrefix("my-agent --fast; ") == true)
    #expect(h.model.title(of: h.model.workspace.activeTab(in: h.main.id)!) == "Custom command")
  }

  @Test func theLoginEnvironmentFeedsDetection() async {
    let h = Harness()
    #expect(h.model.loginEnvironment == nil)
    await h.model.refreshLoginEnvironment()
    #expect(h.model.loginEnvironment?.path != nil)
    // Whatever this machine has installed, the answer came from that PATH.
    #expect(h.model.agentDetection == AgentDetection(path: h.model.loginEnvironment?.path))
  }
}

/// `withObservationTracking`'s handler is `@Sendable`, so the flag it sets
/// cannot be a captured `var`.
private final class Flag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false
  var raised: Bool { lock.withLock { value } }
  func raise() { lock.withLock { value = true } }
}

@Suite @MainActor
struct ReportedAgentWriteTests {
  /// The board and the sidebar's Agents row are drawn from `reportedAgents`,
  /// and an agent reports twice per tool call, so an idle write renders both.
  @Test func aReportSayingWhatTheLastOneSaidWritesNothing() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    let session = tab.focusedSessionID
    func report() {
      h.model.apply(
        SessionStateReport(
          state: .running, sessionID: session, pid: 4242, agent: AgentCatalogue.claudeID))
    }
    report()

    let wrote = Flag()
    withObservationTracking {
      _ = h.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    report()

    #expect(!wrote.raised, "the same agent and pid again")
    #expect(h.model.reportedAgents[session]?.agentID == AgentCatalogue.claudeID)

    withObservationTracking {
      _ = h.model.reportedAgents
    } onChange: {
      wrote.raise()
    }
    h.model.apply(
      SessionStateReport(state: .running, sessionID: session, pid: 99, agent: "codex"))
    #expect(wrote.raised, "a different agent still lands")
  }
}
