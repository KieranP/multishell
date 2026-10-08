import MultishellCore

extension AppModel {
  /// The menus' Rename: the row swaps its name for a field. The project is
  /// opened first, one collapsed by its chevron or the filter leaving no row.
  public func beginRenamingWorktree(_ worktree: Worktree) {
    guard workspace.worktree(worktree.id) != nil else { return }
    if isFilteringSidebar {
      expandWhileFiltering(worktree.projectID)
    } else if let project = workspace.project(worktree.projectID), !project.isExpanded {
      setExpanded(true, for: project)
    }
    renamingWorktreeID = worktree.id
  }

  /// The field's Return, or the focus leaving it. Ignored once the rename has
  /// ended, so an Escape is not undone by the commit losing focus triggers.
  public func commitWorktreeRename(of id: Worktree.ID, to name: String) {
    guard renamingWorktreeID == id else { return }
    renameWorktree(id, to: name)
  }

  /// The field's Escape: the name stays as it was.
  public func cancelRenamingWorktree() {
    renamingWorktreeID = nil
  }

  /// Sets or clears a name without going through the field; `nil` is the
  /// menu's Use Branch Name.
  public func renameWorktree(_ id: Worktree.ID, to name: String?) {
    renamingWorktreeID = nil
    store.setCustomName(name, forWorktree: id)
  }
}
