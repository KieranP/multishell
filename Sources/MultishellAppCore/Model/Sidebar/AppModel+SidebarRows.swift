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

  /// The pane rows under this worktree's sidebar row, in tab order: only the
  /// one in view has them, so one set takes room at a time.
  func sidebarPanes(of worktree: Worktree) -> [SidebarPane] {
    guard isInView(worktree) else { return [] }
    let focused = workspace.activeTab(in: worktree.id)?.focusedSessionID
    // Once per call, not per pane: a session lookup is a scan of them all.
    let sessions = workspace.sessions(in: worktree.id).keyedByID()
    return workspace.tabs(in: worktree.id).flatMap { tab in
      tab.sessionIDs.enumerated().compactMap { offset, id in
        sessions[id].map { session in
          let agentID = agentIDAtThePrompt(of: session)
          return SidebarPane(
            id: id,
            title: title(ofPane: session, in: tab),
            position: .of(paneAt: offset, in: tab),
            isFocused: id == focused,
            state: state(ofPane: id),
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
    return Set(entries.filter(\.isExpanded).flatMap { $0.worktrees.map(\.id) })
  }
}
