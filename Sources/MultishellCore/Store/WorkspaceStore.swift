import Foundation
import Observation

/// The single place workspace state changes.
///
/// Views observe and call these methods; they never mutate `workspace`
/// directly and never touch a process. That is what lets a second GUI reuse
/// this unchanged.
@Observable
@MainActor
public final class WorkspaceStore {
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
    guard workspace.project(id) != nil, workspace.worktrees(of: id) != discovered else { return }
    let survivors = Set(discovered.map(\.id))
    for worktree in workspace.worktrees(of: id) where !survivors.contains(worktree.id) {
      discardWorktree(worktree.id)
    }
    workspace.worktrees.removeAll { $0.projectID == id }
    workspace.worktrees.append(contentsOf: discovered)
  }

  /// A row's worktree can be stale by the time the click lands, if a refresh
  /// dropped it in between; selecting nothing beats selecting a ghost.
  public func selectWorktree(_ id: Worktree.ID?) {
    guard let id else { return workspace.selectedWorktreeID = nil }
    guard workspace.worktree(id) != nil else { return }
    workspace.selectedWorktreeID = id
  }

  /// Forgets a worktree and everything hanging off it. Removing the
  /// directory itself is git's job, not the store's.
  private func discardWorktree(_ id: Worktree.ID) {
    workspace.worktrees.removeAll { $0.id == id }
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

  /// Reorders within a worktree. `tabs` is one flat array, so the move is
  /// done on the worktree's slice and written back in place.
  public func moveTab(_ id: TerminalTab.ID, before target: TerminalTab.ID) {
    guard
      let moving = workspace.tab(id), let anchor = workspace.tab(target),
      moving.worktreeID == anchor.worktreeID, id != target
    else { return }
    var siblings = workspace.tabs(in: moving.worktreeID)
    siblings.removeAll { $0.id == id }
    guard let slot = siblings.firstIndex(where: { $0.id == target }) else { return }
    siblings.insert(moving, at: slot)

    var reordered = siblings.makeIterator()
    for index in workspace.tabs.indices where workspace.tabs[index].worktreeID == moving.worktreeID
    {
      workspace.tabs[index] = reordered.next()!
    }
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

  /// Splits the focused pane of a tab. Not reachable from the MVP UI; the
  /// store supports it so shipping splits is a view change.
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
}
