extension Workspace {
  public var selectedWorktree: Worktree? {
    selectedWorktreeID.flatMap(worktree)
  }

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

  public func fileTab(_ id: FileTab.ID) -> FileTab? {
    fileTabs.first { $0.id == id }
  }

  func fileTabIndex(_ id: FileTab.ID) -> Int? {
    fileTabs.firstIndex { $0.id == id }
  }

  /// A tab of either kind.
  public func workspaceTab(_ id: WorkspaceTab.ID) -> WorkspaceTab? {
    if let tab = tab(id) { return .terminal(tab) }
    return fileTab(id).map(WorkspaceTab.file)
  }

  /// The worktree's tab showing `path`, of which there is at most one.
  func fileTab(showing path: String, in worktree: Worktree.ID) -> FileTab? {
    fileTabs.first { $0.worktreeID == worktree && $0.path == path }
  }

  func fileTabs(in worktree: Worktree.ID) -> [FileTab] {
    fileTabs.filter { $0.worktreeID == worktree }
  }

  /// How many tabs a worktree holds, of either kind.
  public func workspaceTabCount(in worktree: Worktree.ID) -> Int {
    tabs.count { $0.worktreeID == worktree } + fileTabs.count { $0.worktreeID == worktree }
  }

  public func group(_ id: TabGroup.ID) -> TabGroup? {
    tabGroups.first { $0.id == id }
  }

  func groupIndex(_ id: TabGroup.ID) -> Int? {
    tabGroups.firstIndex { $0.id == id }
  }

  /// Cycling stays inside the tab's own group, wrapping at either end, and
  /// steps through both kinds in strip order.
  public func neighbour(
    ofTab id: WorkspaceTab.ID,
    _ direction: CycleDirection,
  ) -> WorkspaceTab? {
    guard let current = workspaceTab(id) else { return nil }
    return workspaceTabs(inGroup: current.groupID).neighbour(of: id, direction)
  }

  public func worktrees(of project: Project.ID) -> [Worktree] {
    worktrees.filter { $0.projectID == project }
  }

  /// Every tab of a worktree, whichever group it is in.
  public func tabs(in worktree: Worktree.ID) -> [TerminalTab] {
    tabs.filter { $0.worktreeID == worktree }
  }

  /// One group's tabs of both kinds, in strip order: its `tabOrder`.
  public func workspaceTabs(inGroup group: TabGroup.ID) -> [WorkspaceTab] {
    guard let order = self.group(group)?.tabOrder else { return [] }
    let terminals = tabs.filter { $0.groupID == group }.keyedByID()
    let files = fileTabs.filter { $0.groupID == group }.keyedByID()
    return order.compactMap { id in
      terminals[id].map(WorkspaceTab.terminal) ?? files[id].map(WorkspaceTab.file)
    }
  }

  /// The group two tabs are both in, `nil` where they are in two or one is gone.
  public func sharedGroup(
    of tab: WorkspaceTab.ID,
    and other: WorkspaceTab.ID,
  ) -> TabGroup.ID? {
    guard let first = workspaceTab(tab), let second = workspaceTab(other),
      first.groupID == second.groupID
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

  /// The terminal tab a group shows, `nil` where it shows a file.
  public func shownTab(ofGroup group: TabGroup) -> TerminalTab? {
    group.shownTabID.flatMap { tab($0) }
  }

  public func shownWorkspaceTab(ofGroup group: TabGroup) -> WorkspaceTab? {
    group.shownTabID.flatMap { workspaceTab($0) }
  }

  /// The terminal tab the user is working in: the focused group's. What
  /// Cmd+T, a split and a rename act on; `nil` where that group shows a file.
  public func activeTab(in worktree: Worktree.ID) -> TerminalTab? {
    focusedGroup(in: worktree).flatMap { shownTab(ofGroup: $0) }
  }

  /// The focused group's tab, of either kind: what closing a tab acts on.
  public func activeWorkspaceTab(in worktree: Worktree.ID) -> WorkspaceTab? {
    focusedGroup(in: worktree).flatMap { shownWorkspaceTab(ofGroup: $0) }
  }

  /// Every terminal tab on screen for a worktree, one per group showing one.
  /// Anything meaning "the user can see this" asks here, not `activeTab`.
  public func shownTabs(in worktree: Worktree.ID) -> [TerminalTab] {
    groups(in: worktree).compactMap { shownTab(ofGroup: $0) }
  }

  /// The branches a project's worktrees have checked out, which git refuses
  /// to check out a second time.
  public func checkedOutBranches(of project: Project.ID) -> Set<String> {
    Set(worktrees(of: project).compactMap(\.branch))
  }
}
