import Foundation
import MultishellCore

/// The quick switcher's rows, unmatched, in sidebar order.
extension AppModel {
  private typealias SidebarPlace = (project: Project, worktree: Worktree)

  private func quickSwitcherProjects() -> [QuickSwitcherItem] {
    workspace.projects.map { project in
      QuickSwitcherItem(
        target: .project(project.id),
        kind: .project(
          settings: effectiveSettings(for: project),
          isMissing: missingProjects.contains(project.id),
        ),
        title: project.name,
        location: project.path.path.abbreviatingHomeDirectory(),
      )
    }
  }

  func quickSwitcherWorktrees() -> [QuickSwitcherItem] {
    let sessions = sessionIDsByWorktree
    return quickSwitcherWorktrees(in: quickSwitcherSidebarOrder(sessions: sessions), sessions)
  }

  /// Those of `ids` still listed, in the order given.
  func quickSwitcherWorktrees(_ ids: [Worktree.ID]) -> [QuickSwitcherItem] {
    let workspace = workspace
    let places: [SidebarPlace] = ids.compactMap { id in
      guard let worktree = workspace.worktree(id),
        let project = workspace.project(worktree.projectID)
      else { return nil }
      return (project, worktree)
    }
    return quickSwitcherWorktrees(in: places, sessionIDsByWorktree)
  }

  /// Every pane and file or All changes tab, the saved ones of worktrees not yet opened
  /// included, worktree by worktree in sidebar order, each in its strips' order.
  func quickSwitcherPanesAndFileTabs() -> [QuickSwitcherItem] {
    quickSwitcherTabRows(
      in: quickSwitcherSidebarOrder(sessions: sessionIDsByWorktree),
      agentsOnly: false,
    )
  }

  /// The agents, built without the shells' rows, which the lists of agents
  /// never show.
  func quickSwitcherAgents() -> [QuickSwitcherItem] {
    quickSwitcherTabRows(
      in: quickSwitcherSidebarOrder(sessions: sessionIDsByWorktree),
      agentsOnly: true,
    )
  }

  /// Panes and file tabs, then worktrees, then projects, the sidebar's order
  /// worked out once for both.
  func quickSwitcherPlaces() -> [QuickSwitcherItem] {
    let sessions = sessionIDsByWorktree
    let order = quickSwitcherSidebarOrder(sessions: sessions)
    return quickSwitcherTabRows(in: order, agentsOnly: false)
      + quickSwitcherWorktrees(in: order, sessions) + quickSwitcherProjects()
  }

  func quickSwitcherFile(_ path: String, in worktreeID: Worktree.ID) -> QuickSwitcherItem {
    let nsPath = path as NSString
    return QuickSwitcherItem(
      target: .file(path: path, worktreeID: worktreeID),
      kind: .file,
      title: nsPath.lastPathComponent,
      location: nsPath.deletingLastPathComponent,
    )
  }

  func quickSwitcherCommands(_ items: [PlatformMenuItem]) -> [QuickSwitcherItem] {
    items.map { item in
      QuickSwitcherItem(
        target: .command(path: item.path),
        kind: .command,
        title: item.switcherTitle ?? item.path.last ?? "",
        location: item.isInAppMenu
          ? QuickSwitcherItem.path([t("command.application")] + item.path.dropFirst().dropLast())
          : QuickSwitcherItem.path(item.path.dropLast()),
        shortcut: item.shortcut,
        isChecked: item.isChecked,
      )
    }
  }

  /// Reads the model once a list, as `orderedWorktrees` does, not once a row.
  private func quickSwitcherWorktrees(
    in order: [SidebarPlace],
    _ sessions: SessionIDsByWorktree,
  ) -> [QuickSwitcherItem] {
    let workspace = workspace
    let states = sessionStates
    let statuses = statuses
    return order.map { project, worktree in
      let branch =
        workspace.customName(of: worktree.id).map { "\(worktree.name) (\($0))" } ?? worktree.name
      return QuickSwitcherItem(
        target: .worktree(worktree.id),
        kind: .worktree,
        title: QuickSwitcherItem.path([project.name, branch]),
        location: "",
        state: states.state(ofWorktree: worktree.id, sessions: sessions[worktree.id]),
        status: statuses[worktree.id],
      )
    }
  }

  /// An agent's pane ends its path with the agent, so `claude` finds it, and
  /// reads its own title after; a shell's ends with its title.
  private func quickSwitcherPane(
    _ session: TerminalSession,
    agentID: String?,
    in tab: TerminalTab,
    of worktree: Worktree,
    at offset: Int,
    place: String,
    states: SessionStates,
    titles: [TerminalSession.ID: String],
  ) -> QuickSwitcherItem {
    let paneTitle = shownTitle(ofPane: session, in: tab, of: worktree, titles: titles)
    return QuickSwitcherItem(
      target: .pane(session.id),
      kind: agentID.map { .agent(id: $0) } ?? .shell,
      title: QuickSwitcherItem.path([place, agentID.map(agentDisplayName) ?? paneTitle]),
      location: agentID == nil ? "" : paneTitle,
      position: .of(paneAt: offset, in: tab),
      state: states[.session(session.id)],
      since: states.since(.session(session.id)),
    )
  }

  /// Where a tab is, the start of its row's path.
  private func quickSwitcherPlace(of worktree: Worktree, in project: Project) -> String {
    QuickSwitcherItem.path([project.name, worktree.name])
  }

  /// Every pane and tab, or only the agents' panes, worktree by worktree in
  /// `order` and each in its strips' order.
  private func quickSwitcherTabRows(
    in order: [SidebarPlace],
    agentsOnly: Bool,
  ) -> [QuickSwitcherItem] {
    let sessions = workspace.sessions.keyedByID()
    let tabsByWorktree = workspace.workspaceTabsByWorktree()
    let agents = promptAgents
    let titles = sessionTitles
    return order.flatMap { project, worktree in
      let place = quickSwitcherPlace(of: worktree, in: project)
      return (tabsByWorktree[worktree.id] ?? []).flatMap { tab -> [QuickSwitcherItem] in
        switch tab {
        case .terminal(let tab):
          tab.sessionIDs.enumerated().compactMap { offset, id in
            guard let session = sessions[id] else { return nil }
            let agentID = agents.agentID(of: session)
            guard !agentsOnly || agentID != nil else { return nil }
            return quickSwitcherPane(
              session,
              agentID: agentID,
              in: tab,
              of: worktree,
              at: offset,
              place: place,
              states: agents.states,
              titles: titles,
            )
          }

        case .file(let tab):
          agentsOnly ? [] : [quickSwitcherFileTab(tab, at: place)]

        case .allChanges(let tab):
          agentsOnly ? [] : [quickSwitcherAllChangesTab(tab, at: place)]
        }
      }
    }
  }

  private func quickSwitcherFileTab(_ tab: FileTab, at place: String) -> QuickSwitcherItem {
    QuickSwitcherItem(
      target: .fileTab(tab.id),
      kind: .fileTab,
      title: QuickSwitcherItem.path([place, tab.fileName]),
      location: "",
    )
  }

  private func quickSwitcherAllChangesTab(
    _ tab: AllChangesTab,
    at place: String,
  ) -> QuickSwitcherItem {
    QuickSwitcherItem(
      target: .allChangesTab(tab.id),
      kind: .allChangesTab,
      title: QuickSwitcherItem.path([place, title(of: tab)]),
      location: "",
    )
  }

  /// Every worktree as the sidebar lists it, projects in order and each one's
  /// worktrees by its sort, its hidden ones after the rest.
  private func quickSwitcherSidebarOrder(sessions: SessionIDsByWorktree) -> [SidebarPlace] {
    let workspace = workspace
    return workspace.projects.flatMap { project in
      let ordered = orderedWorktrees(
        workspace.worktrees(of: project.id),
        in: project,
        sessions: sessions,
      )
      let shown = ordered.filter { !workspace.isHidden($0) }
      let hidden = ordered.filter(workspace.isHidden)
      return (shown + hidden).map { (project, $0) }
    }
  }
}
