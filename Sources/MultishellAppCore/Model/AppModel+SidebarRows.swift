import MultishellCore

extension AppModel {
  public func sidebarWorktree(_ worktree: Worktree) -> SidebarWorktree {
    SidebarWorktree(
      worktree: worktree, customName: customName(of: worktree),
      isRenaming: renamingWorktreeID == worktree.id, panes: sidebarPanes(of: worktree))
  }

  /// The pane rows under this worktree's sidebar row, in tab order: only the
  /// one in view has them, so one set takes room at a time.
  func sidebarPanes(of worktree: Worktree) -> [SidebarPane] {
    guard isInView(worktree) else { return [] }
    let focused = workspace.activeTab(in: worktree.id)?.focusedSessionID
    // Once per call, not per pane: a session lookup is a scan of them all.
    let sessions = Dictionary(
      workspace.sessions(in: worktree.id).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    return workspace.tabs(in: worktree.id).flatMap { tab in
      tab.sessionIDs.enumerated().compactMap { offset, id in
        sessions[id].map { session in
          let agentID = agentAtThePrompt(of: session)
          return SidebarPane(
            id: id,
            title: title(ofPane: session, in: tab),
            position: .of(paneAt: offset, in: tab),
            isFocused: id == focused,
            state: state(ofPane: id),
            subagents: subagents(ofPane: id),
            agentID: agentID,
            agentName: agentID.map(agentDisplayName))
        }
      }
    }
  }
}
