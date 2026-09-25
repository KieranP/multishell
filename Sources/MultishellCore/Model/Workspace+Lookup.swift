extension Workspace {
  public func project(_ id: Project.ID) -> Project? {
    projects.first { $0.id == id }
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
    return tabs(in: current.groupID).neighbour(of: id, direction)
  }

  /// The name the user gave this worktree, or `nil` where they gave none.
  public func customName(of worktree: Worktree.ID) -> String? {
    worktreeNames[worktree]
  }

  /// What the sidebar and the header call a worktree: the user's name where
  /// there is one, else the branch, SHA or folder `Worktree.name` gives.
  public func displayName(of worktree: Worktree) -> String {
    worktreeNames[worktree.id] ?? worktree.name
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
  public func tabs(in group: TabGroup.ID) -> [TerminalTab] {
    tabs.filter { $0.groupID == group }
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

  /// The user's name for a tab, else the focused pane's starting title. What
  /// a running shell reports is runtime state the GUI layers on top.
  public func title(of tab: TerminalTab) -> String {
    if let custom = tab.customTitle { return custom }
    return session(tab.focusedSessionID)?.displayTitle ?? t("tab.shell")
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

  /// The tab a group shows.
  public func activeTab(in group: TabGroup) -> TerminalTab? {
    group.activeTabID.flatMap { tab($0) }
  }

  /// The tab the user is working in: the focused group's. What Cmd+T,
  /// Close Pane, a split and a rename all act on.
  public func activeTab(in worktree: Worktree.ID) -> TerminalTab? {
    focusedGroup(in: worktree).flatMap { activeTab(in: $0) }
  }

  /// Every tab on screen for a worktree, one per group. Anything meaning
  /// "the user can see this" asks here, not `activeTab`.
  public func shownTabs(in worktree: Worktree.ID) -> [TerminalTab] {
    groups(in: worktree).compactMap { activeTab(in: $0) }
  }

  /// Every pane across a worktree's tabs, whichever group each is in.
  public func paneCount(in worktree: Worktree.ID) -> Int {
    tabs(in: worktree).reduce(0) { $0 + $1.sessionIDs.count }
  }

  /// The branches a project's worktrees have checked out, which git refuses
  /// to check out a second time.
  public func checkedOutBranches(of project: Project.ID) -> Set<String> {
    Set(worktrees(of: project).compactMap(\.branch))
  }
}
