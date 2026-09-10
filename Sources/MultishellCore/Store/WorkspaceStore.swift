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
    workspace.sessions.removeAll { $0.worktreeID == id }
    workspace.activeTabByWorktree[id] = nil
    if workspace.selectedWorktreeID == id {
      workspace.selectedWorktreeID = nil
    }
  }
}

// MARK: - Tabs

extension WorkspaceStore {
  @discardableResult
  public func openTab(
    in worktreeID: Worktree.ID,
    title: String? = nil,
    command: [String]? = nil,
    agentID: String? = nil
  ) -> TerminalTab? {
    guard
      let session = makeSession(in: worktreeID, title: title, command: command, agentID: agentID)
    else { return nil }
    workspace.sessions.append(session)
    let tab = TerminalTab(worktreeID: worktreeID, session: session.id)
    workspace.tabs.append(tab)
    workspace.activeTabByWorktree[worktreeID] = tab.id
    return tab
  }

  public func closeTab(_ id: TerminalTab.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == id }) else { return }
    removeTab(at: index)
  }

  /// Reorders within a worktree, landing just before or just after `target`.
  /// `tabs` is one flat array, so the move is done on the worktree's slice
  /// and written back in place.
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) {
    guard
      let moving = workspace.tab(id), let anchor = workspace.tab(target),
      moving.worktreeID == anchor.worktreeID, id != target
    else { return }
    var siblings = workspace.tabs(in: moving.worktreeID)
    siblings.removeAll { $0.id == id }
    guard let slot = siblings.firstIndex(where: { $0.id == target }) else { return }
    siblings.insert(moving, at: placement == .before ? slot : slot + 1)

    var reordered = siblings.makeIterator()
    for index in workspace.tabs.indices where workspace.tabs[index].worktreeID == moving.worktreeID
    {
      workspace.tabs[index] = reordered.next()!
    }
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
  /// The tab lands last in the destination's strip and takes the active slot
  /// there, since a tab dragged somewhere is the one being worked in. The
  /// worktree it left falls back to its last remaining tab.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, to worktreeID: Worktree.ID) -> Bool {
    guard
      let index = workspace.tabs.firstIndex(where: { $0.id == id }),
      let destination = workspace.worktree(worktreeID),
      workspace.tabs[index].worktreeID != worktreeID
    else { return false }

    var tab = workspace.tabs.remove(at: index)
    let source = tab.worktreeID
    tab.worktreeID = worktreeID
    // `tabs(in:)` filters in array order, so appending is landing last.
    workspace.tabs.append(tab)

    let moving = Set(tab.sessionIDs)
    for index in workspace.sessions.indices where moving.contains(workspace.sessions[index].id) {
      workspace.sessions[index].worktreeID = worktreeID
      workspace.sessions[index].workingDirectory = destination.path
    }

    if workspace.activeTabByWorktree[source] == id {
      workspace.activeTabByWorktree[source] = workspace.tabs(in: source).last?.id
    }
    workspace.activeTabByWorktree[worktreeID] = id
    return true
  }

  /// Empty or whitespace clears the custom title, so the shell's takes over
  /// again.
  public func setCustomTitle(_ title: String?, forTab id: TerminalTab.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.id == id }) else { return }
    let trimmed = title?.trimmingCharacters(in: .whitespaces) ?? ""
    workspace.tabs[index].customTitle = trimmed.isEmpty ? nil : trimmed
  }

  public func activateTab(_ id: TerminalTab.ID) {
    guard let tab = workspace.tab(id) else { return }
    workspace.activeTabByWorktree[tab.worktreeID] = id
  }

  private func removeTab(at index: Int) {
    let tab = workspace.tabs[index]
    let closing = Set(tab.sessionIDs)
    workspace.sessions.removeAll { closing.contains($0.id) }
    workspace.tabs.remove(at: index)

    if workspace.activeTabByWorktree[tab.worktreeID] == tab.id {
      workspace.activeTabByWorktree[tab.worktreeID] = workspace.tabs(in: tab.worktreeID).last?.id
    }
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

  public func focusSession(_ id: TerminalSession.ID) {
    guard let index = workspace.tabs.firstIndex(where: { $0.root.contains(id) }) else { return }
    workspace.tabs[index].focusedSessionID = id
    workspace.activeTabByWorktree[workspace.tabs[index].worktreeID] = workspace.tabs[index].id
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
