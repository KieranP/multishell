import MultishellCore

/// Which menu commands can act now, which the quick switcher lists; the menus
/// keep every item on, and each action is a no-op where it cannot act.
extension AppModel {
  /// New Tab, New Shell Tab and New Agent Tab: a worktree in view, no create or
  /// remove running in it.
  public var canOpenTab: Bool {
    worktreeInView.map { !isBusy($0.id) } ?? false
  }

  /// Split Right and Down: a terminal tab in view to split.
  public var canSplitPane: Bool {
    canOpenTab && worktreeIDInView.flatMap(workspace.activeTab(in:)) != nil
  }

  /// Next and Previous Tab: another tab in the strip to go to.
  public var canActivateAnotherTab: Bool {
    workspaceTabInView.map { workspace.neighbour(ofTab: $0.id, .next) != nil } ?? false
  }

  public var canMoveActiveTabToNewGroup: Bool {
    focusedGroup.map { canMoveTabToNewGroup(from: $0.id) } ?? false
  }

  /// Focus Next and Previous Group: another group in view to go to.
  public var canFocusAnotherGroup: Bool {
    worktreeIDInView.map { workspace.groups(in: $0).count > 1 } ?? false
  }

  /// Open in Editor: a worktree in view, on the rule a shell starting there follows.
  public var canOpenWorktreeInEditor: Bool { canOpenTab }

  /// Close Pane and Close Tab, in the workspace window; Cmd+W closes any other.
  public var hasTabToClose: Bool { workspaceTabInView != nil }

  /// The Files panel: on, it can always be turned off; off, it needs a worktree
  /// in view to list.
  public var canToggleFilesPanel: Bool { showsFilesPanel || filesPanelWorktree != nil }

  /// New Worktree…: a project to make it in.
  public var canStartNewWorktree: Bool { !workspace.projects.isEmpty }
}
