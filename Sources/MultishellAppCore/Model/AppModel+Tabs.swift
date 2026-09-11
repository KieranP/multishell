import Foundation
import MultishellCore

// MARK: - Tabs

extension AppModel {
  /// The project a worktree-scoped command should act on: the selected
  /// worktree's project, or the only project when nothing is selected yet.
  public var activeProject: Project? {
    if let worktree = workspace.selectedWorktree {
      return workspace.project(worktree.projectID)
    }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// The worktree whose terminals are on screen: the selected one unless the
  /// board covers them. Everything acting on the tab in front asks here.
  var worktreeInView: Worktree? {
    showsAgentBoard ? nil : workspace.selectedWorktree
  }

  /// The worktree in view when a shell may start in it. `nil` otherwise,
  /// the missing-directory alert already raised.
  func worktreeReadyForShell() -> Worktree? {
    guard let worktree = worktreeInView, !isBusy(worktree.id), requireDirectory(of: worktree)
    else { return nil }
    return worktree
  }

  /// Cmd+T: the preferred agent where auto-start is on, else a plain shell.
  /// A strip's button names its column; the keystroke names none.
  public func newTab(in group: TabGroup.ID? = nil) {
    guard let worktree = worktreeReadyForShell() else { return }
    openFirstOrNewTab(in: worktree, on: .byUser, group: group)
    sync()
  }

  /// Cmd+Shift+T: always a plain shell, so one stays reachable when every
  /// New Tab starts an agent.
  public func newShellTab() {
    guard let worktree = worktreeReadyForShell() else { return }
    store.openTab(in: worktree.id)
    sync()
  }

  /// What a new tab is by default here, and the first tab a worktree gets
  /// when selected or created.
  func openFirstOrNewTab(in worktree: Worktree, on opening: TabOpening, group: TabGroup.ID? = nil) {
    if let project = project(of: worktree),
      autoStartsAgent(in: project, on: opening),
      let agentID = workspace.preferredAgentID(for: project)
    {
      store.openTab(
        in: worktree.id, group: group, title: agentDisplayName(agentID), agentID: agentID)
    } else {
      store.openTab(in: worktree.id, group: group)
    }
  }

  /// Whether a worktree with no tabs gets one for this reason. A worktree
  /// whose project has gone follows the global.
  func opensTab(in worktree: Worktree, on opening: TabOpening) -> Bool {
    switch opening {
    case .byUser: true
    case .onSelect:
      if let project = project(of: worktree) {
        workspace.opensTerminalOnSelect(for: project)
      } else {
        workspace.opensTerminalOnSelect
      }
    case .onCreate:
      if let project = project(of: worktree) {
        workspace.opensTerminalOnCreate(for: project)
      } else {
        workspace.opensTerminalOnCreate
      }
    case .never: false
    }
  }

  /// The worktree's project with the repository's file layered in: reading
  /// `project.settings` would pass over what the file says.
  private func project(of worktree: Worktree) -> Project? {
    workspace.project(worktree.projectID).map { resolved($0) }
  }

  /// Whether that tab runs the agent. Only a create asks the create setting;
  /// everything else follows auto-start on tab open.
  private func autoStartsAgent(in project: Project, on opening: TabOpening) -> Bool {
    switch opening {
    case .onCreate: workspace.autoStartsAgentOnCreate(for: project)
    case .byUser, .onSelect, .never: workspace.autoStartsAgent(for: project)
    }
  }

  /// Cmd+W closes the focused pane; the tab goes with its last pane.
  public func closeActivePane() {
    closeInShownTab { .pane($0.focusedSessionID) }
  }

  /// Cmd+Shift+W closes the whole tab, panes and all.
  public func closeActiveTab() {
    closeInShownTab { .tab($0.id) }
  }

  /// A middle click on a tab, closing it active or not. No key-window dance:
  /// the click landed here, so this window is the one being acted in.
  public func closeTab(_ id: TerminalTab.ID) {
    guard let tab = workspace.tab(id) else { return }
    requestClose(.tab(id), in: tab)
  }

  /// The confirmed half of a close that found a working agent.
  public func confirmPendingClose() {
    guard let pending = pendingClose else { return }
    pendingClose = nil
    perform(pending)
  }

  /// A close whose subject has gone has nothing left to ask. Run from
  /// `sync`, so every path that takes one away is covered.
  func prunePendingClose() {
    switch pendingClose {
    case .pane(let id) where workspace.session(id) == nil: pendingClose = nil
    case .tab(let id) where workspace.tab(id) == nil: pendingClose = nil
    default: break
    }
  }

  // The three entry points above meet here, the keystrokes through
  // `closeInShownTab`, which has to find the tab first.

  /// Both keystrokes. One issued in a settings window closes that window
  /// instead, and nothing happens with no tab on screen.
  private func closeInShownTab(_ closing: (TerminalTab) -> PendingClose) {
    guard platform.workspaceWindowIsKey else { return platform.closeKeyWindow() }
    guard let worktree = worktreeInView?.id, let tab = workspace.activeTab(in: worktree)
    else { return }
    requestClose(closing(tab), in: tab)
  }

  /// A close whose panes hold a working agent is asked about rather than
  /// done; `PendingClose` says which shells each form would end.
  private func requestClose(_ close: PendingClose, in tab: TerminalTab) {
    if close.sessionIDs(in: tab).contains(where: { sessionStates[.session($0)] == .running }) {
      pendingClose = close
      return
    }
    perform(close)
  }

  private func perform(_ close: PendingClose) {
    switch close {
    case .pane(let id): store.closeSession(id)
    case .tab(let id): store.closeTab(id)
    }
    sync()
  }

  public func activate(_ tab: TerminalTab) {
    store.activateTab(tab.id)
    sync()
  }

  /// Moves `id` beside `target`, possibly in another column. A move leaving
  /// the strip reading the same writes nothing, the shuffle having done it.
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) {
    guard changesTheStrip(id, placement, target) else { return }
    store.moveTab(id, placement, target)
  }

  /// A tab landing in another column always changes something, if only
  /// which column it is in. Inside one column it is a question of order.
  private func changesTheStrip(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) -> Bool {
    guard
      let moving = workspace.tab(id), let anchor = workspace.tab(target),
      moving.groupID == anchor.groupID
    else { return true }
    return TabShuffle.reorders(
      id, placement, of: target, in: workspace.tabs(in: moving.groupID).map(\.id))
  }

  /// A tab dragged onto a worktree's row, shells and all, the destination
  /// turned to. `false` where the move cannot happen; see tabs-and-columns.md.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, to worktreeID: Worktree.ID) -> Bool {
    guard
      let source = workspace.tab(id)?.worktreeID, source != worktreeID, !isBusy(source),
      let worktree = workspace.worktree(worktreeID), !isBusy(worktreeID),
      requireDirectory(of: worktree), store.moveTab(id, to: worktreeID)
    else { return false }
    // Warmed here, not left to the selection: the shells are live, and a
    // cold destination is one the next reconcile would close them for.
    warmWorktrees.insert(worktreeID)
    select(worktree)
    return true
  }

  public func renameTab(_ id: TerminalTab.ID, to title: String?) {
    store.setCustomTitle(title, forTab: id)
  }

  public func splitActivePane(_ axis: SplitAxis) {
    guard let worktree = worktreeReadyForShell(), let tab = workspace.activeTab(in: worktree.id)
    else { return }
    store.splitFocusedPane(of: tab.id, axis: axis)
    sync()
  }

  public func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    store.setSplitWeights(weights, at: path, ofTab: tabID)
  }

  public func selectNextTab() { selectTab(.after) }
  public func selectPreviousTab() { selectTab(.before) }

  /// The tab one place along the strip, wrapping at either end.
  func selectTab(_ direction: TerminalTab.Placement) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.activeTab(in: worktree),
      let next = direction == .after
        ? workspace.tab(after: current.id) : workspace.tab(before: current.id)
    else { return }
    activate(next)
  }
}
