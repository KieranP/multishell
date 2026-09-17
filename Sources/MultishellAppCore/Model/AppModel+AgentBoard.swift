import Foundation
import MultishellCore

extension AppModel {
  /// Every live pane, flattened into a card. Rebuilt each read, a cache
  /// being one more thing that can disagree with the sidebar.
  public var agentBoardCards: [AgentBoardCard] {
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
  public func isAgentPane(_ session: TerminalSession) -> Bool {
    reportedAgents[session.id] != nil || session.agentID != nil
  }

  /// How many cards each column holds, without building one: a card carries
  /// a title, and the sidebar would re-render on every prompt.
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
}
