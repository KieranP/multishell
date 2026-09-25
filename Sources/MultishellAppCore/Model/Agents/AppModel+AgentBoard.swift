import Foundation
import MultishellCore

extension AppModel {
  /// Every live pane, flattened into a card.
  var agentBoardCards: [AgentBoardCard] {
    let projectNames = Dictionary(
      workspace.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    let worktreesByID = Dictionary(
      workspace.worktrees.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var tabsBySession: [TerminalSession.ID: (tab: TerminalTab, position: PanePosition?)] =
      [:]
    for tab in workspace.tabs {
      for (offset, id) in tab.sessionIDs.enumerated() {
        tabsBySession[id] = (tab, .of(paneAt: offset, in: tab))
      }
    }

    return workspace.sessions.compactMap { session in
      guard liveSessionIDs.contains(session.id), let (tab, position) = tabsBySession[session.id],
        let worktree = worktreesByID[session.worktreeID]
      else { return nil }
      let key = SessionStates.Key.session(session.id)
      return AgentBoardCard(
        id: session.id,
        tabID: tab.id,
        worktreeID: worktree.id,
        occupant: occupant(of: session),
        title: title(ofPane: session, in: tab),
        projectName: projectNames[worktree.projectID] ?? "",
        worktreeName: workspace.displayName(of: worktree),
        state: sessionStates[key],
        since: sessionStates.since(key),
        note: sessionStates.note(key),
        status: statuses[worktree.id],
        subagents: sessionStates.subagents(key),
        position: position)
    }
  }

  /// Held until anything the build read changes, the build being tracked so
  /// no input can be missed; see Docs/design/agents.md.
  public var agentBoard: AgentBoard {
    // What a view holding the cached board is told through.
    _ = agentBoardGeneration
    if let cachedAgentBoard { return cachedAgentBoard }
    let board = withObservationTracking {
      AgentBoard(cards: agentBoardCards, showsAllTerminals: showsAllTerminals)
    } onChange: { [weak self] in
      MainActor.assumeIsolated { self?.dropCachedAgentBoard() }
    }
    agentBoardBuilds += 1
    cachedAgentBoard = board
    return board
  }

  private func dropCachedAgentBoard() {
    cachedAgentBoard = nil
    agentBoardGeneration &+= 1
  }

  /// How many cards each column holds, without building one: a card carries
  /// a title, and the sidebar would re-render on every prompt.
  var agentLaneCounts: [AgentBoardLane: Int] {
    var counts: [AgentBoardLane: Int] = [:]
    for session in workspace.sessions
    where liveSessionIDs.contains(session.id) && (showsAllTerminals || isAgentPane(session)) {
      counts[AgentBoardLane.of(sessionStates[.session(session.id)]), default: 0] += 1
    }
    return counts
  }

  /// The counts the sidebar entry carries, in the order it draws them; see
  /// `AgentBoardLane.summarised`.
  public var agentSidebarCounts: [(lane: AgentBoardLane, count: Int)] {
    let counts = agentLaneCounts
    return AgentBoardLane.summarised.map { ($0, counts[$0] ?? 0) }
  }

  /// Who is at the prompt, by name.
  private func occupant(of session: TerminalSession) -> AgentBoardCard.Occupant {
    if let agentID = agentAtThePrompt(of: session) {
      return .agent(id: agentID, name: AgentCatalogue.displayName(agentID))
    }
    return .shell(URL(filePath: shellPath(forWorktree: session.worktreeID)).lastPathComponent)
  }

  /// The board fills the detail area, the selection left alone so its shells
  /// stay live. The sweep makes the first frame honest; see `watchedPIDs`.
  public func showAgentBoard() {
    showsAgentBoard = true
    sweepGonePIDs()
    updatePIDWatch()
  }

  /// The panes are back in front of the user, and the focused one's Done seen
  /// unless the caller does its own seen-clearing. The PID watch is told.
  func hideAgentBoard(markingInViewSeen marksSeen: Bool = true) {
    guard showsAgentBoard else { return }
    showsAgentBoard = false
    updatePIDWatch()
    if marksSeen { markInViewSeen() }
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
  }

  public func setShowsAllTerminals(_ shows: Bool) {
    guard shows != showsAllTerminals else { return }
    showsAllTerminals = shows
    // The badge counts what the Waiting column shows, and the filter just
    // changed what that is.
    updateDockBadge()
  }

  /// A click on a card: turn to its pane and leave the board. The card stays,
  /// moving to Idle if what was shown was a Done.
  public func open(_ card: AgentBoardCard) {
    guard let tab = workspace.tab(card.tabID), let worktree = workspace.worktree(card.worktreeID)
    else { return }
    // The board is left by `select`, and only once it agrees to go: a
    // missing directory raises an alert and stays put.
    guard select(worktree) else { return }
    show(pane: card.id, in: tab)
  }

  /// The count on the app's icon: what the Waiting column shows. Pushed, the
  /// port being a plain protocol with no way to watch a value.
  func updateDockBadge() {
    let waiting = agentLaneCounts[.waiting] ?? 0
    guard waiting != badgedWaitingCount else { return }
    badgedWaitingCount = waiting
    platform.setBadgeCount(waiting > 0 ? waiting : nil)
  }
}
