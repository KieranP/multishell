import MultishellCore

extension AppModel {
  public func sidebarWorktree(_ worktree: Worktree) -> SidebarWorktree {
    SidebarWorktree(
      worktree: worktree,
      customName: customName(of: worktree),
      isRenaming: renamingWorktreeID == worktree.id,
      panes: sidebarPanes(of: worktree),
    )
  }

  /// The worktree rows carry the dots while they show; the project's row
  /// stands in for them only once they are collapsed away.
  public func projectRowState(
    _ id: Project.ID,
    isExpanded: Bool,
    sessions: SessionIDsByWorktree,
  ) -> SessionState? {
    isExpanded ? nil : state(ofProject: id, sessions: sessions)
  }

  /// The pane rows under this worktree's sidebar row, group by group in strip
  /// order: only the one in view has them, so one set takes room at a time.
  func sidebarPanes(of worktree: Worktree) -> [SidebarPane] {
    guard isInView(worktree) else { return [] }
    let focused = workspace.activeTab(in: worktree.id)?.focusedSessionID
    // Once per call, not per pane: a session lookup is a scan of them all.
    let sessions = workspace.sessions(in: worktree.id).keyedByID()
    // `tabs` keeps each group's places, so a tab opened in the first group after a
    // second was made sits after the second's there.
    let stripOrder = workspace.groups(in: worktree.id)
      .flatMap { workspace.workspaceTabs(inGroup: $0.id) }
      .compactMap { tab -> TerminalTab? in
        guard case .terminal(let terminal) = tab else { return nil }
        return terminal
      }
    return stripOrder.flatMap { tab in
      tab.sessionIDs.enumerated().compactMap { offset, id in
        sessions[id].map { session in
          let agentID = agentIDAtThePrompt(of: session)
          return SidebarPane(
            id: id,
            title: shownTitle(ofPane: session, in: tab, of: worktree),
            position: .of(paneAt: offset, in: tab),
            isFocused: id == focused,
            state: state(ofPane: id),
            since: sessionStates.since(.session(id)),
            workers: workers(ofPane: id),
            agentID: agentID,
            agentName: agentID.map(agentDisplayName),
          )
        }
      }
    }
  }

  /// The rows the sidebar draws, once a round: asked per row, the filter
  /// looked up the project and folded the text for every worktree.
  func sidebarRowIDs(
    filteredBy text: String? = nil,
    collapsing collapsed: Set<Project.ID>? = nil,
  ) -> Set<Worktree.ID> {
    let entries = sidebarEntries(
      filteredBy: text ?? sidebarFilterText,
      collapsing: collapsed ?? projectsCollapsedWhileFiltering,
    )
    return Set(
      entries.filter(\.isExpanded).flatMap { entry in
        (entry.worktrees + (entry.showsHiddenWorktrees ? entry.hiddenWorktrees : [])).map(\.id)
      }
    )
  }
}
