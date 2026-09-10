import Foundation
import MultishellCore

// MARK: - What the board is made of

extension AppModel {
  /// Every live pane, flattened into a card. Rebuilt on each read rather
  /// than cached: it is derived from observed state, and a cache would be
  /// one more thing that can disagree with the sidebar.
  public var agentBoardCards: [AgentBoardCard] {
    let projectNames = Dictionary(
      workspace.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    var tabsBySession: [TerminalSession.ID: TerminalTab] = [:]
    for tab in workspace.tabs {
      for id in tab.sessionIDs { tabsBySession[id] = tab }
    }

    return workspace.sessions.compactMap { session in
      guard liveSessions.contains(session.id), let tab = tabsBySession[session.id],
        let worktree = workspace.worktree(session.worktreeID)
      else { return nil }
      let key = SessionStates.Key.session(session.id)
      return AgentBoardCard(
        id: session.id,
        tabID: tab.id,
        worktreeID: worktree.id,
        occupant: occupant(of: session),
        title: paneTitle(of: session, in: tab),
        projectName: projectNames[worktree.projectID] ?? "",
        worktreeName: workspace.displayName(of: worktree),
        state: sessionStates[key],
        since: sessionStates.since[key],
        note: sessionStates.notes[key],
        status: statuses[worktree.id])
    }
  }

  public var agentBoard: AgentBoard {
    AgentBoard(cards: agentBoardCards, showsShells: showsAllTerminals)
  }

  /// Whether an agent is at this pane's prompt: one reported there, or the
  /// tab was opened to run one. The report wins, because an agent is usually
  /// started by hand in a plain shell tab and a tab opened for one keeps its
  /// `agentID` long after the agent has quit; see `ReportedAgent`, and
  /// `updatePIDWatch`, which takes an entry away once its process has gone.
  ///
  /// The board and the counts beside it both ask this, so the sidebar entry
  /// can never disagree with the columns it is summarising.
  public func isAgentPane(_ session: TerminalSession) -> Bool {
    reportedAgents[session.id] != nil || session.agentID != nil
  }

  /// How many cards each column holds, without building one.
  ///
  /// The sidebar entry and the Dock badge read this rather than the board:
  /// a card carries a pane's title and its worktree's git status, and a
  /// sidebar that read those would re-render every time a shell reported a
  /// new prompt, which is the whole reason titles are kept out of the
  /// workspace.
  public var agentLaneCounts: [AgentBoardLane: Int] {
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
      return .agent(AgentCatalogue.displayName(reported.agentID))
    }
    if let agentID = session.agentID {
      return .agent(AgentCatalogue.displayName(agentID))
    }
    return .shell(
      URL(fileURLWithPath: shellPath(forWorktree: session.worktreeID)).lastPathComponent)
  }

  /// The pane's own title, not its tab's: a split holds several panes under
  /// one strip, and each card is about one of them. What the shell reports
  /// wins, since for a shell running a command that is the command.
  private func paneTitle(of session: TerminalSession, in tab: TerminalTab) -> String {
    sessionTitles[session.id] ?? tab.customTitle ?? session.title
  }
}
