extension Workspace {
  public func project(_ id: Project.ID) -> Project? {
    projects.first { $0.id == id }
  }

  func projectIndex(_ id: Project.ID) -> Int? {
    projects.firstIndex { $0.id == id }
  }

  public func worktree(_ id: Worktree.ID) -> Worktree? {
    worktrees.first { $0.id == id }
  }

  public func session(_ id: TerminalSession.ID) -> TerminalSession? {
    sessions.first { $0.id == id }
  }

  public func tab(_ id: TerminalTab.ID) -> TerminalTab? {
    tabs.first { $0.id == id }
  }

  func tabIndex(_ id: TerminalTab.ID) -> Int? {
    tabs.firstIndex { $0.id == id }
  }

  public func group(_ id: TabGroup.ID) -> TabGroup? {
    tabGroups.first { $0.id == id }
  }

  func groupIndex(_ id: TabGroup.ID) -> Int? {
    tabGroups.firstIndex { $0.id == id }
  }

  public func tab(before tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, .previous)
  }

  public func tab(after tab: TerminalTab.ID) -> TerminalTab? {
    neighbour(of: tab, .next)
  }

  /// Cycling stays inside the tab's own group.
  private func neighbour(
    of id: TerminalTab.ID, _ direction: CycleDirection
  ) -> TerminalTab? {
    guard let current = tab(id) else { return nil }
    return tabs(inGroup: current.groupID).neighbour(of: id, direction)
  }

  public func worktrees(of project: Project.ID) -> [Worktree] {
    worktrees.filter { $0.projectID == project }
  }

  /// Every tab of a worktree, whichever group it is in.
  public func tabs(in worktree: Worktree.ID) -> [TerminalTab] {
    tabs.filter { $0.worktreeID == worktree }
  }

  /// One group's tabs, in strip order. `tabs` is one flat array whose
  /// order is display order, so a move places rather than reorders.
  public func tabs(inGroup group: TabGroup.ID) -> [TerminalTab] {
    tabs.filter { $0.groupID == group }
  }

  /// The group two tabs are both in, `nil` where they are in two or one is gone.
  public func sharedGroup(of tab: TerminalTab.ID, and other: TerminalTab.ID) -> TabGroup.ID? {
    guard let first = self.tab(tab), let second = self.tab(other), first.groupID == second.groupID
    else { return nil }
    return first.groupID
  }

  /// A worktree's groups, left to right.
  public func groups(in worktree: Worktree.ID) -> [TabGroup] {
    tabGroups.filter { $0.worktreeID == worktree }
  }

  /// The group a worktree's keystrokes go to, falling back to its first so
  /// a hand-edited file still shows a strip.
  public func focusedGroup(in worktree: Worktree.ID) -> TabGroup? {
    let worktreeGroups = groups(in: worktree)
    if let id = focusedGroupByWorktree[worktree],
      let group = worktreeGroups.first(where: { $0.id == id })
    {
      return group
    }
    return worktreeGroups.first
  }

  public func sessions(in worktree: Worktree.ID) -> [TerminalSession] {
    sessions.filter { $0.worktreeID == worktree }
  }

  public func tab(owning session: TerminalSession.ID) -> TerminalTab? {
    tabs.first { $0.root.contains(session) }
  }

  func tabIndex(owning session: TerminalSession.ID) -> Int? {
    tabs.firstIndex { $0.root.contains(session) }
  }

  public var selectedWorktree: Worktree? {
    selectedWorktreeID.flatMap(worktree)
  }

  public func shownTab(ofGroup group: TabGroup) -> TerminalTab? {
    group.shownTabID.flatMap { tab($0) }
  }

  /// The tab the user is working in: the focused group's. What Cmd+T,
  /// Close Pane, a split and a rename all act on.
  public func activeTab(in worktree: Worktree.ID) -> TerminalTab? {
    focusedGroup(in: worktree).flatMap { shownTab(ofGroup: $0) }
  }

  /// Every tab on screen for a worktree, one per group. Anything meaning
  /// "the user can see this" asks here, not `activeTab`.
  public func shownTabs(in worktree: Worktree.ID) -> [TerminalTab] {
    groups(in: worktree).compactMap { shownTab(ofGroup: $0) }
  }

  /// The branches a project's worktrees have checked out, which git refuses
  /// to check out a second time.
  public func checkedOutBranches(of project: Project.ID) -> Set<String> {
    Set(worktrees(of: project).compactMap(\.branch))
  }
}
