import Foundation
import MultishellCore

extension AppModel {
  /// Every live pane, flattened into a card. Rebuilt each read, a cache
  /// being one more thing that can disagree with the sidebar.
  var agentBoardCards: [AgentBoardCard] {
    let projectNames = Dictionary(
      workspace.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    let worktreesByID = Dictionary(
      workspace.worktrees.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var tabsBySession:
      [TerminalSession.ID: (tab: TerminalTab, position: AgentBoardCard.Position?)] =
        [:]
    for tab in workspace.tabs {
      for (index, id) in tab.sessionIDs.enumerated() {
        let position =
          tab.sessionIDs.count > 1
          ? AgentBoardCard.Position(index: index + 1, count: tab.sessionIDs.count) : nil
        tabsBySession[id] = (tab, position)
      }
    }

    return workspace.sessions.compactMap { session in
      guard liveSessions.contains(session.id), let (tab, position) = tabsBySession[session.id],
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

  public var agentBoard: AgentBoard {
    AgentBoard(cards: agentBoardCards, showsShells: showsAllTerminals)
  }

  /// Whether an agent is at this pane's prompt, the report winning over the
  /// tab's own id. Asked by the board and its counts alike.
  func isAgentPane(_ session: TerminalSession) -> Bool {
    reportedAgents[session.id] != nil || commandAgents[session.id] != nil
      || session.agentID != nil
  }

  /// How many cards each column holds, without building one: a card carries
  /// a title, and the sidebar would re-render on every prompt.
  var agentLaneCounts: [AgentBoardLane: Int] {
    var counts: [AgentBoardLane: Int] = [:]
    for session in workspace.sessions
    where liveSessions.contains(session.id) && (showsAllTerminals || isAgentPane(session)) {
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
    if let reported = reportedAgents[session.id] {
      return .agent(id: reported.agentID, name: AgentCatalogue.displayName(reported.agentID))
    }
    if let running = commandAgents[session.id] {
      return .agent(id: running, name: AgentCatalogue.displayName(running))
    }
    if let agentID = session.agentID {
      return .agent(id: agentID, name: AgentCatalogue.displayName(agentID))
    }
    return .shell(
      URL(fileURLWithPath: shellPath(forWorktree: session.worktreeID)).lastPathComponent)
  }

  /// The board fills the detail area, the selection left alone so its shells
  /// stay live. The sweep makes the first frame honest; see `watchedPIDs`.
  public func showAgentBoard() {
    showsAgentBoard = true
    sweepGonePIDs()
    updatePIDWatch()
  }

  /// The panes are back in front of the user, and the focused one's Done seen.
  func hideAgentBoard() {
    guard showsAgentBoard else { return }
    leaveAgentBoard()
    markFocusedPaneSeen()
  }

  /// The menu item and its keystroke, which go back to the worktree the
  /// second time rather than doing nothing.
  public func toggleAgentBoard() {
    if showsAgentBoard { hideAgentBoard() } else { showAgentBoard() }
  }

  /// Puts the panes back without the seen-clearing, for callers doing their
  /// own. The watch is told, what it polls depending on the board.
  func leaveAgentBoard() {
    guard showsAgentBoard else { return }
    showsAgentBoard = false
    updatePIDWatch()
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
