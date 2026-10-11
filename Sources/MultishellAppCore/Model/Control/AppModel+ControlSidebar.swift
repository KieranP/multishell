import MultishellCore

extension AppModel {
  /// Built from the calls the sidebar's own views make, so it lists what they draw.
  func replyToListSidebar() -> ControlReply {
    let sessions = sessionIDsByWorktree
    let entries = sidebarEntries
    let projects = entries.map { entry in
      let worktrees =
        entry.isExpanded
        ? orderedWorktrees(entry.worktrees, in: entry.project, sessions: sessions) : []
      return SidebarRowListing.ProjectRow(
        id: ControlID.project(entry.project.id),
        name: entry.project.name,
        isExpanded: entry.isExpanded,
        state: projectRowState(entry.project.id, isExpanded: entry.isExpanded, sessions: sessions),
        worktrees: worktrees.map { sidebarWorktreeRow($0, sessions: sessions) },
      )
    }
    return .json(
      SidebarRowListing(
        filterText: sidebarFilterText,
        projects: projects,
        emptyMessage: sidebarEmptyMessage(showing: entries),
      )
    )
  }

  /// As typed into the sidebar's filter; empty puts the field away.
  func replyToFilterSidebar(_ text: String) -> ControlReply {
    if text.isEmpty { setShowsSidebarFilter(false) } else { sidebarFilterText = text }
    return .done
  }

  private func sidebarWorktreeRow(
    _ worktree: Worktree,
    sessions: SessionIDsByWorktree,
  ) -> SidebarRowListing.WorktreeRow {
    let row = sidebarWorktree(worktree)
    return SidebarRowListing.WorktreeRow(
      id: ControlID.worktree(worktree.id),
      name: displayName(of: worktree),
      isRenaming: row.isRenaming,
      isInView: isInView(worktree),
      state: state(ofWorktree: worktree.id, sessions: sessions),
      terminalCount: row.shownTerminalCount(of: sessions[worktree.id].count),
      panes: row.panes.map { pane in
        SidebarRowListing.PaneRow(
          id: pane.id,
          title: pane.title,
          isFocused: pane.isFocused,
          state: pane.state,
          agent: pane.agentID,
        )
      },
    )
  }
}
