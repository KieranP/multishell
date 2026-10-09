import MultishellCore

extension AppModel {
  private func polledRowIDs(
    filteredBy text: String? = nil,
    collapsing collapsed: Set<Project.ID>? = nil,
  ) -> Set<Worktree.ID> {
    let onSidebar = sidebarRowIDs(filteredBy: text, collapsing: collapsed)
    return Set(workspace.worktrees.filter { isStatusWanted($0, onSidebar: onSidebar) }.map(\.id))
  }

  /// Rows the filter hid went unread, so those it brings back are read, as
  /// opening a project's are; after a pause, not at every keystroke.
  func scheduleRevealedRowsRead(from oldText: String, collapsing oldCollapsed: Set<Project.ID>) {
    let polledBefore =
      pendingRevealedRowsRead?.polledThroughout
      ?? polledRowIDs(filteredBy: oldText, collapsing: oldCollapsed)
    let polledThroughout = polledBefore.intersection(polledRowIDs())
    pendingRevealedRowsRead?.task.cancel()
    let task = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self else { return }
      pendingRevealedRowsRead = nil
      let revealed = polledRowIDs().subtracting(polledThroughout)
      await refreshStatuses { revealed.contains($0.id) }
    }
    pendingRevealedRowsRead = (polledThroughout, task)
  }
}
