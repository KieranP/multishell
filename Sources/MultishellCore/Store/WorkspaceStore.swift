import Foundation
import Observation

/// The single place workspace state changes.
///
/// Views observe and call these methods; they never mutate `workspace`
/// directly and never touch a process. That is what lets a second GUI reuse
/// this unchanged.
///
/// One file, long as it is, and not an extension per collection: `private`
/// in Swift reaches the whole file and no further, so the setters have to
/// sit beside the property to write it. Splitting them out means widening
/// that to `internal(set)`, which is the guarantee above given up.
@Observable
@MainActor
public final class WorkspaceStore {
  /// `private(set)`, so nothing outside this file writes the workspace.
  public private(set) var workspace: Workspace

  @ObservationIgnored private let snapshot: WorkspaceSnapshot

  public init(workspace: Workspace = Workspace(), snapshot: WorkspaceSnapshot = WorkspaceSnapshot())
  {
    self.workspace = workspace
    self.snapshot = snapshot
  }

  /// Loads saved state. `loadError` is set, not thrown, so the app still
  /// starts and can tell the user what happened.
  public static func restored(
    from snapshot: WorkspaceSnapshot = WorkspaceSnapshot()
  ) -> (store: WorkspaceStore, loadError: (any Error)?) {
    do {
      var workspace = try snapshot.load()
      workspace.repairReferences()
      return (WorkspaceStore(workspace: workspace, snapshot: snapshot), nil)
    } catch {
      return (WorkspaceStore(workspace: Workspace(), snapshot: snapshot), error)
    }
  }

  public func save() throws {
    try snapshot.save(workspace)
  }
}

// MARK: - Projects

extension WorkspaceStore {
  @discardableResult
  public func addProject(at path: URL) -> Project {
    let project = Project(path: path)
    if let existing = workspace.project(project.id) { return existing }
    workspace.projects.append(project)
    return project
  }

  public func removeProject(_ id: Project.ID) {
    workspace.projects.removeAll { $0.id == id }
    for worktree in workspace.worktrees(of: id) {
      discardWorktree(worktree.id)
    }
  }

  /// Same contract as SwiftUI's `move(fromOffsets:toOffset:)`, which lives in
  /// SwiftUI rather than the standard library and so is not available here.
  public func moveProjects(from source: IndexSet, to destination: Int) {
    guard
      (0...workspace.projects.count).contains(destination),
      source.allSatisfy(workspace.projects.indices.contains)
    else { return }
    let moving = source.map { workspace.projects[$0] }
    let shift = source.filter { $0 < destination }.count
    for index in source.sorted(by: >) {
      workspace.projects.remove(at: index)
    }
    workspace.projects.insert(contentsOf: moving, at: destination - shift)
  }

  public func setExpanded(_ expanded: Bool, forProject id: Project.ID) {
    update(project: id) { $0.isExpanded = expanded }
  }

  public func updateSettings(_ settings: ProjectSettings, forProject id: Project.ID) {
    update(project: id) { $0.settings = settings }
  }

  private func update(project id: Project.ID, _ change: (inout Project) -> Void) {
    guard let index = workspace.projects.firstIndex(where: { $0.id == id }) else { return }
    change(&workspace.projects[index])
  }
}

// MARK: - Worktrees

extension WorkspaceStore {
  /// Replaces a project's worktrees with what git just reported, dropping
  /// tabs whose worktree no longer exists.
  ///
  /// Refreshes are asynchronous, so one can land after its project was
  /// removed; that must not resurrect the worktrees. An unchanged list is
  /// left alone so a watcher tick does not trigger a save and a re-render.
  public func replaceWorktrees(_ discovered: [Worktree], forProject id: Project.ID) {
    guard workspace.project(id) != nil else { return }
    let fresh = discovered.map(keepingKnownCreationDate)
    guard workspace.worktrees(of: id) != fresh else { return }
    let survivors = Set(fresh.map(\.id))
    for worktree in workspace.worktrees(of: id) where !survivors.contains(worktree.id) {
      discardWorktree(worktree.id)
    }
    workspace.worktrees.removeAll { $0.projectID == id }
    workspace.worktrees.append(contentsOf: fresh)
  }

  /// A creation date once read is not forgotten because a later stat could
  /// not answer. A directory on a volume that blinked would otherwise flip
  /// to undated, which is a change: it costs a save and a re-render, and
  /// moves the row to the end of the sidebar's created order and back.
  ///
  /// Only where the fresh listing has no date, so a worktree genuinely
  /// recreated at the same path takes the new one.
  private func keepingKnownCreationDate(_ worktree: Worktree) -> Worktree {
    guard worktree.createdAt == nil, let known = workspace.worktree(worktree.id)?.createdAt
    else { return worktree }
    var kept = worktree
    kept.createdAt = known
    return kept
  }

  /// A row's worktree can be stale by the time the click lands, if a refresh
  /// dropped it in between; selecting nothing beats selecting a ghost.
  public func selectWorktree(_ id: Worktree.ID?) {
    guard let id else { return workspace.selectedWorktreeID = nil }
    guard workspace.worktree(id) != nil else { return }
    workspace.selectedWorktreeID = id
  }

  /// The user's own name for a worktree, shown in place of its branch.
  /// Empty or whitespace clears it, so the branch takes over again.
  public func setCustomName(_ name: String?, forWorktree id: Worktree.ID) {
    guard workspace.worktree(id) != nil else { return }
    let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
    workspace.worktreeNames[id] = trimmed.isEmpty ? nil : trimmed
  }

  /// Forgets a worktree and everything hanging off it. Removing the
  /// directory itself is git's job, not the store's.
  private func discardWorktree(_ id: Worktree.ID) {
    workspace.worktrees.removeAll { $0.id == id }
    workspace.worktreeNames[id] = nil
    workspace.tabs.removeAll { $0.worktreeID == id }
    workspace.tabGroups.removeAll { $0.worktreeID == id }
    workspace.sessions.removeAll { $0.worktreeID == id }
    workspace.focusedGroupByWorktree[id] = nil
    if workspace.selectedWorktreeID == id {
      workspace.selectedWorktreeID = nil
    }
  }
}

// MARK: - Tabs

extension WorkspaceStore {
  /// Opens a tab in one column: the one named, else the worktree's focused
  /// column, else a first column made for it.
  @discardableResult
  public func openTab(
    in worktreeID: Worktree.ID,
    group: TabGroup.ID? = nil,
    title: String? = nil,
    command: [String]? = nil,
    agentID: String? = nil
  ) -> TerminalTab? {
    guard
      let session = makeSession(in: worktreeID, title: title, command: command, agentID: agentID),
      let column = resolvedGroup(group, in: worktreeID)
    else { return nil }
    workspace.sessions.append(session)
    // `tabs(in:)` filters in array order, so appending is landing last in
    // this column's strip whichever column it is.
    let tab = TerminalTab(worktreeID: worktreeID, groupID: column, session: session.id)
    workspace.tabs.append(tab)
    setActiveTab(tab.id, ofGroup: column)
    workspace.focusedGroupByWorktree[worktreeID] = column
    return tab
  }

  public func closeTab(_ id: TerminalTab.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == id }) else { return }
    removeTab(at: index)
  }

  /// Moves a tab to sit just before or just after `target`, which may be in
  /// another column of the same worktree. `tabs` is one flat array whose
  /// order is display order, so placing the tab next to its anchor puts it
  /// in the right place in the anchor's column with nothing to rewrite.
  ///
  /// A move that changes column activates the tab there, since a tab
  /// dragged somewhere is the one being worked in; a reorder inside one
  /// column leaves the active tab alone.
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) {
    guard
      let movingIndex = workspace.tabs.firstIndex(where: { $0.id == id }),
      let anchorIndex = workspace.tabs.firstIndex(where: { $0.id == target }),
      workspace.tabs[movingIndex].worktreeID == workspace.tabs[anchorIndex].worktreeID,
      id != target
    else { return }

    let source = workspace.tabs[movingIndex].groupID
    let destination = workspace.tabs[anchorIndex].groupID
    var tab = workspace.tabs.remove(at: movingIndex)
    tab.groupID = destination
    // Taking the tab out shifts the anchor down by one where it sat after it.
    let slot = anchorIndex > movingIndex ? anchorIndex - 1 : anchorIndex
    workspace.tabs.insert(tab, at: placement == .before ? slot : slot + 1)

    guard source != destination else { return }
    settle(group: source)
    activateTab(id)
  }

  /// A tab dropped on a column's strip past its last tab, or on its New Tab
  /// button: it lands last there. A drop on a tab answers with a placement
  /// instead, there being a tab to be before or after.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, toEndOf groupID: TabGroup.ID) -> Bool {
    guard
      let index = workspace.tabs.firstIndex(where: { $0.id == id }),
      let destination = workspace.group(groupID),
      workspace.tabs[index].worktreeID == destination.worktreeID,
      workspace.tabs[index].groupID != groupID
    else { return false }

    var tab = workspace.tabs.remove(at: index)
    let source = tab.groupID
    tab.groupID = groupID
    workspace.tabs.append(tab)
    settle(group: source)
    activateTab(id)
    return true
  }

  /// Moves a tab, panes and all, to another worktree.
  ///
  /// The shells keep running; nothing is typed at their prompts and nothing
  /// is restarted. What moves is the tab's own place: its worktree, and the
  /// directory its panes start in, which the destination decides from now
  /// on. The two are kept together because both are read at launch, and a
  /// tab that opened one project's shell in another project's directory
  /// would be neither.
  ///
  /// It lands last in the destination's focused column and takes the active
  /// slot there, since a tab dragged somewhere is the one being worked in.
  /// The column it left falls back to its last remaining tab, or goes.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, to worktreeID: Worktree.ID) -> Bool {
    guard
      let index = workspace.tabs.firstIndex(where: { $0.id == id }),
      let destination = workspace.worktree(worktreeID),
      workspace.tabs[index].worktreeID != worktreeID,
      let column = resolvedGroup(nil, in: worktreeID)
    else { return false }

    var tab = workspace.tabs.remove(at: index)
    let source = tab.groupID
    tab.worktreeID = worktreeID
    tab.groupID = column
    // `tabs(in:)` filters in array order, so appending is landing last.
    workspace.tabs.append(tab)

    let moving = Set(tab.sessionIDs)
    for index in workspace.sessions.indices where moving.contains(workspace.sessions[index].id) {
      workspace.sessions[index].worktreeID = worktreeID
      workspace.sessions[index].workingDirectory = destination.path
    }

    settle(group: source)
    setActiveTab(id, ofGroup: column)
    workspace.focusedGroupByWorktree[worktreeID] = column
    return true
  }

  /// Empty or whitespace clears the custom title, so the shell's takes over
  /// again.
  public func setCustomTitle(_ title: String?, forTab id: TerminalTab.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == id }) else { return }
    let trimmed = title?.trimmingCharacters(in: .whitespaces) ?? ""
    workspace.tabs[index].customTitle = trimmed.isEmpty ? nil : trimmed
  }

  /// Shows a tab in its own column and hands that column the focus: the tab
  /// the user just clicked is the one they are working in.
  public func activateTab(_ id: TerminalTab.ID) {
    guard let tab = workspace.tab(id) else { return }
    setActiveTab(id, ofGroup: tab.groupID)
    workspace.focusedGroupByWorktree[tab.worktreeID] = tab.groupID
  }

  private func removeTab(at index: Int) {
    let tab = workspace.tabs[index]
    let closing = Set(tab.sessionIDs)
    workspace.sessions.removeAll { closing.contains($0.id) }
    workspace.tabs.remove(at: index)
    settle(group: tab.groupID)
  }
}

// MARK: - Tab groups

extension WorkspaceStore {
  /// Moves a tab into a column of its own beside `neighbour`, which gives up
  /// half its width the way splitting a pane halves the pane.
  ///
  /// `nil` when nothing moved, so a drag springs back rather than appearing
  /// to do something: an unknown tab or column, one belonging to another
  /// worktree, or the only tab of the very column it would land beside,
  /// which would leave that column and go straight back into a new one at
  /// the same place. Its only tab landing beside a *different* column is a
  /// real move, and allowed.
  @discardableResult
  public func moveTabToNewGroup(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, of neighbour: TabGroup.ID
  ) -> TabGroup? {
    guard
      let tabIndex = workspace.tabs.firstIndex(where: { $0.id == id }),
      let groupIndex = workspace.tabGroups.firstIndex(where: { $0.id == neighbour }),
      workspace.tabGroups[groupIndex].worktreeID == workspace.tabs[tabIndex].worktreeID,
      workspace.tabs[tabIndex].groupID != neighbour || workspace.tabs(in: neighbour).count > 1
    else { return nil }

    let source = workspace.tabs[tabIndex].groupID
    let worktreeID = workspace.tabGroups[groupIndex].worktreeID
    let share = TabGroup.usableWeight(workspace.tabGroups[groupIndex].weight / 2)
    workspace.tabGroups[groupIndex].weight = share
    let group = TabGroup(worktreeID: worktreeID, weight: share, activeTabID: id)
    // Beside the neighbour in the flat array, which is what puts it beside
    // it on screen; a group of another worktree in between changes nothing.
    workspace.tabGroups.insert(group, at: placement == .before ? groupIndex : groupIndex + 1)
    workspace.tabs[tabIndex].groupID = group.id
    settle(group: source)
    workspace.focusedGroupByWorktree[worktreeID] = group.id
    return group
  }

  /// Written back when the divider between two columns is dragged, so a
  /// layout survives relaunch. Relative shares, like a split's weights.
  public func setGroupWeights(_ weights: [Double], in worktreeID: Worktree.ID) {
    let columns = workspace.groups(in: worktreeID)
    guard weights.count == columns.count, weights.allSatisfy({ $0.isFinite && $0 > 0 }) else {
      return
    }
    var next = weights.makeIterator()
    for index in workspace.tabGroups.indices
    where workspace.tabGroups[index].worktreeID == worktreeID {
      workspace.tabGroups[index].weight = next.next()!
    }
  }

  /// Which column the worktree's keystrokes go to. A click in a pane does
  /// this through `focusSession`; the menu items name a column outright.
  public func focusGroup(_ id: TabGroup.ID) {
    guard let group = workspace.group(id) else { return }
    workspace.focusedGroupByWorktree[group.worktreeID] = id
  }

  /// The column an operation acts on: the one named, the worktree's focused
  /// one, or a first column made for it. `nil` for a worktree that does not
  /// exist, or a column that is not one of its own.
  private func resolvedGroup(_ id: TabGroup.ID?, in worktreeID: Worktree.ID) -> TabGroup.ID? {
    guard workspace.worktree(worktreeID) != nil else { return nil }
    if let id {
      return workspace.group(id)?.worktreeID == worktreeID ? id : nil
    }
    if let focused = workspace.focusedGroup(in: worktreeID) { return focused.id }
    let group = TabGroup(worktreeID: worktreeID)
    workspace.tabGroups.append(group)
    workspace.focusedGroupByWorktree[worktreeID] = group.id
    return group.id
  }

  private func setActiveTab(_ id: TerminalTab.ID?, ofGroup groupID: TabGroup.ID) {
    guard let index = workspace.tabGroups.firstIndex(where: { $0.id == groupID }) else { return }
    workspace.tabGroups[index].activeTabID = id
  }

  /// A column after a tab left it: another of its own tabs showing, or the
  /// column itself gone, since a column never stands empty.
  ///
  /// The focus then goes to the column that slid into its place, or to the
  /// last one where it was the rightmost — the answer a tab strip gives when
  /// the active tab closes, one level out.
  private func settle(group groupID: TabGroup.ID) {
    guard let index = workspace.tabGroups.firstIndex(where: { $0.id == groupID }) else { return }
    let worktreeID = workspace.tabGroups[index].worktreeID
    let remaining = workspace.tabs(in: groupID)

    guard remaining.isEmpty else {
      if let active = workspace.tabGroups[index].activeTabID,
        remaining.contains(where: { $0.id == active })
      {
        return
      }
      workspace.tabGroups[index].activeTabID = remaining.last?.id
      return
    }

    let slot = workspace.groups(in: worktreeID).firstIndex { $0.id == groupID } ?? 0
    workspace.tabGroups.remove(at: index)
    guard workspace.focusedGroupByWorktree[worktreeID] == groupID else { return }
    let survivors = workspace.groups(in: worktreeID)
    workspace.focusedGroupByWorktree[worktreeID] =
      survivors.isEmpty ? nil : survivors[min(slot, survivors.count - 1)].id
  }
}

// MARK: - Sessions and panes

extension WorkspaceStore {
  /// Closes one terminal. If it was the tab's only pane the tab goes with it;
  /// otherwise the pane tree collapses around it.
  public func closeSession(_ id: TerminalSession.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.root.contains(id) }) else { return }
    workspace.sessions.removeAll { $0.id == id }

    guard let remaining = workspace.tabs[index].root.removing(id) else {
      removeTab(at: index)
      return
    }
    workspace.tabs[index].root = remaining
    if workspace.tabs[index].focusedSessionID == id {
      workspace.tabs[index].focusedSessionID = remaining.sessionIDs[0]
    }
  }

  /// A click in a pane, reported back by the engine: the pane takes the
  /// focus, and its tab and column take it with it.
  public func focusSession(_ id: TerminalSession.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.root.contains(id) }) else { return }
    workspace.tabs[index].focusedSessionID = id
    activateTab(workspace.tabs[index].id)
  }

  /// Splits the focused pane of a tab, the new pane taking the focus.
  @discardableResult
  public func splitFocusedPane(
    of tabID: TerminalTab.ID, axis: SplitAxis, command: [String]? = nil
  ) -> TerminalSession? {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == tabID }) else { return nil }
    let tab = workspace.tabs[index]
    guard let session = makeSession(in: tab.worktreeID, title: nil, command: command) else {
      return nil
    }

    workspace.sessions.append(session)
    workspace.tabs[index].root = tab.root.splitting(
      tab.focusedSessionID, with: session.id, axis: axis)
    workspace.tabs[index].focusedSessionID = session.id
    return session
  }

  /// Written back when a divider is dragged, so a layout survives relaunch.
  public func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == tabID }) else { return }
    workspace.tabs[index].root = workspace.tabs[index].root.settingWeights(weights, at: path)
  }

  private func makeSession(
    in worktreeID: Worktree.ID,
    title: String?,
    command: [String]?,
    agentID: String? = nil
  ) -> TerminalSession? {
    guard let worktree = workspace.worktree(worktreeID) else { return nil }
    return TerminalSession(
      worktreeID: worktreeID,
      workingDirectory: worktree.path,
      title: title ?? defaultTitle(for: command),
      command: command,
      agentID: agentID
    )
  }

  private func defaultTitle(for command: [String]?) -> String {
    guard let executable = command?.first else { return "Shell" }
    return URL(fileURLWithPath: executable).lastPathComponent
  }
}

// MARK: - Appearance

extension WorkspaceStore {
  public func setTheme(_ id: Theme.ID) {
    workspace.appearance.themeID = id
  }

  public func setFont(name: String?, size: Double) {
    workspace.appearance.fontName = name
    workspace.appearance.fontSize = size
  }

  public func setUIFontSize(_ size: Double) {
    workspace.appearance.uiFontSize = size
  }

  public func setTerminalEngine(_ engine: TerminalEngine) {
    workspace.terminalEngine = engine
  }

  public func setWorktreeDefaults(_ defaults: WorktreeSettings) {
    workspace.worktreeDefaults = defaults
  }

  public func setNotifications(_ preference: NotificationPreference) {
    workspace.notifications = preference
  }
}

// MARK: - Agents

extension WorkspaceStore {
  public func setPreferredAgent(_ id: String?) {
    workspace.preferredAgentID = id
  }

  public func setCustomAgentCommand(_ command: String) {
    workspace.customAgentCommand = command
  }

  public func setAutoStartAgent(_ enabled: Bool) {
    workspace.autoStartAgent = enabled
  }

  public func setAutoStartAgentOnCreate(_ enabled: Bool) {
    workspace.autoStartAgentOnCreate = enabled
  }
}

// MARK: - Shell, editor and selection

extension WorkspaceStore {
  public func setDefaultShell(_ path: String?) {
    workspace.defaultShell = path
  }

  public func setCustomShellPath(_ path: String) {
    workspace.customShellPath = path
  }

  public func setPreferredEditor(_ id: String?) {
    workspace.preferredEditorID = id
  }

  public func setCustomEditorCommand(_ command: String) {
    workspace.customEditorCommand = command
  }

  public func setOpensTerminalOnSelect(_ enabled: Bool) {
    workspace.opensTerminalOnSelect = enabled
  }

  public func setOpensTerminalOnCreate(_ enabled: Bool) {
    workspace.opensTerminalOnCreate = enabled
  }
}

// MARK: - Worktree listing

extension WorkspaceStore {
  public func setWorktreeSortOrder(_ order: WorktreeSortOrder) {
    workspace.worktreeSortOrder = order
  }

  public func setShowsActiveWorktreesFirst(_ enabled: Bool) {
    workspace.showsActiveWorktreesFirst = enabled
  }
}

// MARK: - Worktree removal

extension WorkspaceStore {
  public func setConfirmsWorktreeRemoval(_ enabled: Bool) {
    workspace.confirmsWorktreeRemoval = enabled
  }

  public func setDeletesBranchWithWorktree(_ enabled: Bool) {
    workspace.deletesBranchWithWorktree = enabled
  }

  /// Negative reads as no limit, like zero.
  public func setHookTimeoutSeconds(_ seconds: Int) {
    workspace.hookTimeoutSeconds = max(0, seconds)
  }
}
