import Foundation
import MultishellCore

extension AppModel {
  /// Every live pane, flattened into a card.
  var agentBoardCards: [AgentBoardCard] {
    let projectNames = workspace.projects.keyedByID().mapValues(\.name)
    let worktreesByID = workspace.worktrees.keyedByID()
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
        workers: sessionStates.workers(key),
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
      MainActor.assumeIsolated { self?.invalidateCachedAgentBoard() }
    }
    agentBoardBuilds += 1
    cachedAgentBoard = board
    return board
  }

  private func invalidateCachedAgentBoard() {
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
  /// `AgentBoardLane.sidebarLanes`. An empty lane is neither drawn nor said.
  public var agentSidebarCounts: [AgentBoardLaneCount] {
    let counts = agentLaneCounts
    return AgentBoardLane.sidebarLanes.compactMap { lane in
      counts[lane].map { AgentBoardLaneCount(lane, $0) }
    }
  }

  /// Who is at the prompt, by name.
  private func occupant(of session: TerminalSession) -> AgentBoardCard.Occupant {
    if let agentID = agentIDAtThePrompt(of: session) {
      return .agent(id: agentID, name: agentDisplayName(agentID))
    }
    return .shell(shellPath(forWorktree: session.worktreeID).executableName)
  }
}
