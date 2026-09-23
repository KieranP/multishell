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

  /// Claude Code started in an outside terminal from a package directory
  /// says that directory, and the worktree containing it is the one meant.
  /// The harness nests `feature` inside `main`, so the deeper one must win.
  @Test func aReportFromInsideAWorktreeMarksTheWorktreeContainingIt() {
    let h = Harness()
    h.model.select(h.main)

    h.source.send(
      SessionStateReport(
        state: .attention, cwd: h.feature.path.appendingPathComponent("packages/api").path))
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
    #expect(h.model.state(ofWorktree: h.main.id) == nil, "the deepest worktree, not the first")

    h.source.send(
      SessionStateReport(state: .error, cwd: h.main.path.appendingPathComponent("featurette").path))
    #expect(h.model.state(ofWorktree: h.main.id) == .error, "a sibling by name is not inside")
    #expect(h.model.state(ofWorktree: h.feature.id) == .attention)
  }

  /// Which worktree is deepest is decided where the match was made: a
  /// worktree added through a symlink chain has a long written path and a
  /// short real one, and a worktree nested inside its real path is deeper.
  @Test func depthIsMeasuredOnTheSpellingThatMatched() throws {
    let h = Harness()
    let files = FileManager.default
    let real = h.main.path.appendingPathComponent("real")
    let inner = real.appendingPathComponent("wt/inner")
    try files.createDirectory(at: inner, withIntermediateDirectories: true)
    let chain = h.main.path.appendingPathComponent("a/b/c")
    try files.createDirectory(at: chain, withIntermediateDirectories: true)
    let link = chain.appendingPathComponent("d")
    try files.createSymbolicLink(at: link, withDestinationURL: real)
    let outer = Worktree(
      path: link.appendingPathComponent("wt"), projectID: h.project.id, head: "c", branch: "outer")
    let nested = Worktree(path: inner, projectID: h.project.id, head: "d", branch: "nested")
    h.store.replaceWorktrees([h.main, outer, nested], forProject: h.project.id)

    let report = inner.appendingPathComponent("src").path
    #expect(h.model.worktree(atPath: report)?.id == nested.id, "the real path is the deeper one")
    #expect(
      h.model.worktree(atPath: real.appendingPathComponent("wt/lib").path)?.id == outer.id,
      "and the outer one is still found through its real path")
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
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.renameWorktree(h.feature.id, to: "Checkout flow")

    h.source.send(SessionStateReport(state: .attention, cwd: h.feature.path.path))

    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.posted.first?.title.contains("Checkout flow") == true)
    #expect(h.notifier.posted.first?.title.contains("feature") == false, "not the branch")
  }

  /// A background worker starting or ending while a prompt is up is
  /// bookkeeping: the banner already on screen is the prompt's, and posting
  /// again under the same key replaces it with a body that says less.
  @Test func aWorkerTickRaisesNoSecondBannerForAPromptAlreadyUp() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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

  /// Seen is the pane with the keyboard, not every pane on screen: a split's
  /// other pane keeps its Done, and its banner is still not raised.
  @Test func aDoneInAnUnfocusedPaneOfASplitStaysUntilThatPaneIsFocused() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    h.source.send(SessionStateReport(state: .done, sessionID: other))
    #expect(h.model.state(ofPane: other) == .done, "on screen, but nobody is in it")
    #expect(h.notifier.posted.isEmpty, "and on screen, so no banner")

    h.source.send(SessionStateReport(state: .done, sessionID: focused))
    #expect(h.model.state(ofPane: focused) == nil, "the focused pane's Done is seen at once")

    h.model.show(pane: other)
    #expect(h.model.state(ofPane: other) == nil, "focusing it is seeing it")
  }

  /// A bell or a title is activity in a pane nobody is in, whether or not
  /// that pane is on screen: seen is the pane with the keyboard.
  @Test func activityInAnUnfocusedPaneOfASplitRaisesItsDot() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: other)
    #expect(h.model.state(ofPane: other) == .done, "on screen, but nobody is in it")

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: focused)
    #expect(h.model.state(ofPane: focused) == nil, "the keyboard is in it")
  }

  /// A click into a pane reaches the model as the engine's focus report,
  /// not as a store call of its own, so that report has to mark it seen too.
  @Test func clickingIntoAPaneSeesItsDone() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let other = tab.sessionIDs.first { $0 != tab.focusedSessionID }!
    h.source.send(SessionStateReport(state: .done, sessionID: other))
    #expect(h.model.state(ofPane: other) == .done)

    h.engine.delegate?.terminalHost(h.engine, didFocus: other)

    #expect(h.model.workspace.tab(tab.id)?.focusedSessionID == other)
    #expect(h.model.state(ofPane: other) == nil, "the keyboard is in it now")
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

    h.model.reconcileSessions(takingFocus: true)
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

  @Test func aStopHeldForABackgroundShellIsPaidAndAnnouncedWhenTheShellExits() async throws {
    let h = Harness()
    h.model.pidPollInterval = .milliseconds(50)
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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
    for _ in 0..<80 where h.model.state(ofPane: session) != .done {
      try await Task.sleep(for: .milliseconds(50))
    }
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
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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
    for _ in 0..<40 where h.model.state(ofPane: session) != .done {
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(h.model.state(ofPane: session) == .done)
    #expect(h.notifier.posted.count == 1)
  }

  /// Whether the agent or its shell is checked first is a set's order, so
  /// several pairs make sure both orders are met.
  @Test func anAgentDyingWithItsShellAnnouncesNothingWhicheverIsSweptFirst() throws {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
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
  /// prune lives in the reconcile rather than beside a removal.
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
    defer {
      source.stop()
      Scratch.removeSocket(path)
    }
    let tmp = try Scratch.directory("socket")
    defer { Scratch.remove(tmp) }
    let store = WorkspaceStore(
      snapshot: WorkspaceSnapshot(fileURL: tmp.appendingPathComponent("state.json")))
    let project = store.addProject(at: tmp)
    let main = Worktree(
      path: tmp, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([main], forProject: project.id)
    let engine = FakeEngine()
    let model = AppModel(
      store: store, host: engine, worktrees: nil,
      watcher: FakeWatcher(), stateSource: source)
    _ = model.startStateSource()
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
    before.store.openTab(in: before.main.id, title: "Flagless", agentID: "flagless")
    before.model.saveNow()

    let (store, _) = WorkspaceStore.restored(from: WorkspaceSnapshot(fileURL: file))
    let engine = FakeEngine()
    let after = AppModel(
      store: store, host: engine, worktrees: nil,
      watcher: FakeWatcher())
    after.select(before.main)

    let byTitle = Dictionary(
      uniqueKeysWithValues: engine.opened.map { (store.workspace.session($0.id)!.title, $0) })
    #expect(byTitle["Claude Code"]?.command?.last?.hasPrefix("claude --continue; ") == true)
    #expect(byTitle["Flagless"]?.command == nil, "no resume flag, so a plain shell keeps the title")
    #expect(after.title(of: store.workspace.tabs(in: before.main.id)[2]) == "Flagless")
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

  /// The sidebar is up while the login shell answers and its PATH is
  /// scanned. A saved agent tab clicked in that window must not be told the
  /// agent is missing, so the environment and what was found on it land together.
  @Test func theEnvironmentIsNotKnownBeforeItsPathHasBeenScanned() async {
    let h = Harness()
    let refresh = Task { await h.model.refreshLoginEnvironment() }
    while h.model.loginEnvironment == nil { try? await Task.sleep(for: .milliseconds(1)) }
    #expect(h.model.shellDetection != .empty, "/etc/shells alone fills this")
    #expect(h.model.agentDetection == AgentDetection(path: h.model.loginEnvironment?.path))
    await refresh.value
  }

  @Test func theNewTabMenuListsWhatWasFoundAndTheCustomCommandOnlyWhenTyped() throws {
    let bin = try fakeBin(["codex", "claude"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let h = Harness()
    h.model.agentDetection = AgentDetection(path: bin.path)

    #expect(h.model.installedAgentIDs == ["claude", "codex"], "catalogue order")

    h.model.setCustomAgentCommand("  ")
    #expect(h.model.installedAgentIDs == ["claude", "codex"], "a blank line is no agent")

    h.model.setCustomAgentCommand("my-agent --fast")
    #expect(h.model.installedAgentIDs == ["claude", "codex", "custom"])

    // Its own store: a second model over the harness's would deselect the
    // worktree under it, `init` clearing the selection.
    let saved = WorkspaceStore(
      snapshot: WorkspaceSnapshot(
        fileURL: Scratch.path("relaunch").appendingPathComponent("state.json")))
    saved.setCustomAgentCommand("my-agent --fast")
    let relaunched = AppModel(
      store: saved, host: FakeEngine(), worktrees: nil, watcher: FakeWatcher())
    #expect(relaunched.installedAgentIDs == ["custom"], "the saved command, before any PATH scan")
  }

  @Test func aNamedAgentTabNeedsNoPreferredAgentAndOpensInTheColumnGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let columns = h.model.workspace.groups(in: h.main.id)
    #expect(h.model.preferredAgentID(for: h.main) == nil)
    h.model.presentedError = nil

    h.model.newAgentTab("opencode", in: columns[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == columns[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == "opencode")
    #expect(h.model.title(of: tab) == "OpenCode")
    #expect(h.model.presentedError == nil, "the strip named the agent, so none was chosen for it")
  }

  @Test func theNewTabMenusShellTabOpensInTheColumnGiven() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setPreferredAgent("claude")
    h.model.setAutoStartAgent(true)
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let columns = h.model.workspace.groups(in: h.main.id)

    h.model.newShellTab(in: columns[0].id)

    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.groupID == columns[0].id)
    #expect(h.model.workspace.session(tab.focusedSessionID)?.agentID == nil)
  }

  @Test func theLoginEnvironmentFeedsDetection() async throws {
    let h = Harness()
    try h.installFakeAgent("claude")
    #expect(h.model.loginEnvironment == nil)
    await h.model.refreshLoginEnvironment()
    #expect(h.model.loginEnvironment?.path != nil)
    #expect(h.model.agentDetection.found[AgentCatalogue.claudeID] != nil, "found on that PATH")
    #expect(h.model.agentDetection == AgentDetection(path: h.model.loginEnvironment?.path))
  }
}

@Suite @MainActor
struct NotificationClickTests {
  /// A banner outlives the worktree it was about: a network volume unmounts
  /// between the report and the click. `select` refuses, and what follows it
  /// would otherwise rewrite the active tab of a worktree nobody can reach.
  @Test func aClickOnAWorktreeThatHasGoneActivatesNothing() throws {
    let h = Harness()
    h.model.select(h.feature)
    let first = try #require(h.model.workspace.activeTab(in: h.feature.id))
    h.model.newTab()
    let second = try #require(h.model.workspace.activeTab(in: h.feature.id))
    #expect(second.id != first.id)
    h.model.select(h.main)
    let selected = h.model.workspace.selectedWorktreeID

    try FileManager.default.removeItem(at: h.feature.path)
    h.model.reveal(.session(first.focusedSessionID))

    #expect(h.model.presentedError?.title == PresentedError.worktreeDirectoryMissing("").title)
    #expect(h.model.workspace.selectedWorktreeID == selected, "the selection stands")
    #expect(
      h.model.workspace.activeTab(in: h.feature.id)?.id == second.id,
      "and the refused worktree's own strip is left as it was")
  }

  @Test func aClickOnAWorktreeThatIsStillThereBringsItsTabUp() throws {
    let h = Harness()
    h.model.select(h.feature)
    let tab = try #require(h.model.workspace.activeTab(in: h.feature.id))
    h.model.select(h.main)

    h.model.reveal(.session(tab.focusedSessionID))

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
  }
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
