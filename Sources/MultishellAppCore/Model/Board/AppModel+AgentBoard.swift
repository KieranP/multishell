import Foundation
import MultishellCore

extension AppModel {
  /// Whether the board shows every terminal or only agent panes. On the model
  /// and not the view, the Dock badge reading the same filter.
  public var showsAllTerminals: Bool { workspace.showsAllTerminals }

  /// Every live pane, flattened into a card.
  var agentBoardCards: [AgentBoardCard] {
    let workspace = workspace
    let projectNames = workspace.projects.keyedByID().mapValues(\.name)
    let worktreesByID = workspace.worktrees.keyedByID()
    var tabsBySession: [TerminalSession.ID: (tab: TerminalTab, position: PanePosition?)] =
      [:]
    for tab in workspace.tabs {
      for (offset, id) in tab.sessionIDs.enumerated() {
        tabsBySession[id] = (tab, .of(paneAt: offset, in: tab))
      }
    }

    let live = liveSessionIDs
    let agents = promptAgents
    let states = sessionStates
    let statuses = statuses
    let titles = sessionTitles
    return workspace.sessions.compactMap { session in
      guard live.contains(session.id), let (tab, position) = tabsBySession[session.id],
        let worktree = worktreesByID[session.worktreeID]
      else { return nil }
      let key = SessionStates.Key.session(session.id)
      return AgentBoardCard(
        id: session.id,
        tabID: tab.id,
        worktreeID: worktree.id,
        occupant: occupant(agentID: agents.agentID(of: session), in: worktree),
        title: shownTitle(ofPane: session, in: tab, of: worktree, titles: titles),
        projectName: projectNames[worktree.projectID] ?? "",
        worktreeName: workspace.displayName(of: worktree),
        state: states[key],
        since: states.since(key),
        note: states.note(key),
        status: statuses[worktree.id],
        workers: states.workers(key),
        position: position,
      )
    }
  }

  /// Held until anything the build read changes, the build being tracked so
  /// no input can be missed; see Docs/design/agents/board-and-pane-rows.md.
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

  /// How many cards each column holds, without building one: a card carries
  /// a title, and the sidebar would re-render on every prompt.
  var boardLaneCounts: [AgentBoardLane: Int] {
    let live = liveSessionIDs
    let agents = promptAgents
    let showsAll = showsAllTerminals
    var counts: [AgentBoardLane: Int] = [:]
    for session in workspace.sessions
    where live.contains(session.id) && (showsAll || agents.agentID(of: session) != nil) {
      counts[AgentBoardLane.of(agents.states[.session(session.id)]), default: 0] += 1
    }
    return counts
  }

  /// The counts the sidebar entry carries, in the order it draws them; see
  /// `AgentBoardLane.sidebarLanes`. An empty lane is neither drawn nor said.
  public var sidebarLaneCounts: [AgentBoardLaneCount] {
    let counts = boardLaneCounts
    return AgentBoardLane.sidebarLanes.compactMap { lane in
      counts[lane].map { AgentBoardLaneCount(lane, $0) }
    }
  }

  private func invalidateCachedAgentBoard() {
    cachedAgentBoard = nil
    agentBoardGeneration &+= 1
  }

  /// Who is at the prompt, by name.
  private func occupant(agentID: String?, in worktree: Worktree) -> AgentBoardCard.Occupant {
    if let agentID {
      return .agent(id: agentID, name: agentDisplayName(agentID))
    }
    return .shell(shellPath(for: worktree).executableName)
  }

  /// Kept for the next launch, as the Files panel's page is.
  public func setShowsAllTerminals(_ shows: Bool) {
    guard shows != showsAllTerminals else { return }
    store.setShowsAllTerminals(shows)
    // The badge counts what the Waiting column shows, and the filter just
    // changed what that is.
    updateDockBadge()
  }
}
