extension Workspace {
  /// The user's name for a tab, else the focused pane's starting title. What
  /// a running shell reports is runtime state the GUI layers on top.
  public func title(of tab: TerminalTab) -> String {
    if let custom = tab.customTitle { return custom }
    return session(tab.focusedSessionID)?.displayTitle ?? t("tab.shell")
  }

  /// The file's name, lengthened to the shortest trailing path that tells it
  /// from every other open file of that name in the worktree: `lib/user.rb`.
  public func title(of tab: FileTab) -> String {
    let parts = tab.path.split(separator: "/")
    let namesakes = fileTabs(in: tab.worktreeID).filter { other in
      other.id != tab.id && other.fileName == tab.fileName
    }.map { $0.path.split(separator: "/") }
    var length = 1
    while length < parts.count,
      namesakes.contains(where: { $0.suffix(length) == parts.suffix(length) })
    {
      length += 1
    }
    return parts.suffix(length).joined(separator: "/")
  }

  public func customName(of worktree: Worktree.ID) -> String? {
    customWorktreeNames[worktree]
  }

  /// What the sidebar and the header call a worktree: the user's name where
  /// there is one, else the branch, SHA or folder `Worktree.name` gives.
  public func displayName(of worktree: Worktree) -> String {
    customWorktreeNames[worktree.id] ?? worktree.name
  }
}
