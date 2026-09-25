import Foundation
import MultishellCore

extension AppModel {
  /// The project a worktree-scoped command should act on: the selected
  /// worktree's project, or the only project when nothing is selected yet.
  public var activeProject: Project? {
    if let worktree = workspace.selectedWorktree {
      return workspace.project(worktree.projectID)
    }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// The project a command should act on while nothing else names one: the
  /// worktree in view's, or the only project. The board names none.
  var projectInView: Project? {
    if let worktree = worktreeInView { return workspace.project(worktree.projectID) }
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
    worktreeInView.flatMap { readyForShell($0) ? $0 : nil }
  }

  /// Whether a shell may start in `worktree`: no create or remove running or
  /// failed there, and its directory present. Every way of starting one asks.
  func readyForShell(_ worktree: Worktree) -> Bool {
    !isBusy(worktree.id) && requireDirectory(of: worktree)
  }

  /// Cmd+T: the preferred agent where auto-start is on, else a plain shell.
  /// A strip's button names its column; the keystroke names none.
  public func newTab(in group: TabGroup.ID? = nil) {
    guard let worktree = worktreeReadyForShell() else { return }
    openFirstOrNewTab(in: worktree, on: .byUser, group: group)
    reconcileSessions(takingFocus: true)
  }

  /// Cmd+Shift+T: always a plain shell, so one stays reachable when every
  /// New Tab starts an agent. A strip's menu names its column.
  public func newShellTab(in group: TabGroup.ID? = nil) {
    guard let worktree = worktreeReadyForShell() else { return }
    store.openTab(in: worktree.id, group: group)
    reconcileSessions(takingFocus: true)
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
  /// the reconcile, so every path that takes one away is covered.
  func prunePendingClose() {
    switch pendingClose {
    case .pane(let id) where workspace.session(id) == nil: pendingClose = nil
    case .tab(let id) where workspace.tab(id) == nil: pendingClose = nil
    default: break
    }
    // A name field whose tab has gone, as a renamed worktree drops its own.
    if let renaming = renamingTabID, workspace.tab(renaming) == nil { renamingTabID = nil }
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
    reconcileSessions(takingFocus: true)
  }

  public func activate(_ tab: TerminalTab) {
    store.activateTab(tab.id)
    reconcileSessions(takingFocus: true)
  }

  /// A pane of the selected worktree brought on screen with the keyboard,
  /// from its sidebar row.
  public func show(pane id: TerminalSession.ID) {
    guard let tab = workspace.tabOwning(id) else { return }
    show(pane: id, in: tab)
  }

  /// The reconcile hands the keyboard to the active tab's focused pane,
  /// which is this one now, so nothing more is needed to land in it.
  func show(pane id: TerminalSession.ID, in tab: TerminalTab) {
    store.activateTab(tab.id)
    store.focusSession(id)
    reconcileSessions(takingFocus: true)
  }

  /// Moves `id` beside `target`, possibly in another column. A move leaving
  /// the strip reading the same writes nothing, the shuffle having done it.
  /// `false` where either tab has gone or they sit in different worktrees.
  @discardableResult
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, _ target: TerminalTab.ID
  ) -> Bool {
    guard changesTheStrip(id, placement, target) else { return true }
    guard store.moveTab(id, placement, target) else { return false }
    // The drop activates the tab in its new column, so without this the engine
    // keeps focus on the one now hidden behind it.
    reconcileSessions(takingFocus: true)
    return true
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
      let worktree = workspace.worktree(worktreeID), readyForShell(worktree),
      store.moveTab(id, to: worktreeID)
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

  /// A double click on a tab: its title swaps for a field.
  public func beginRenamingTab(_ id: TerminalTab.ID) {
    guard workspace.tab(id) != nil else { return }
    renamingTabID = id
  }

  /// The field's Return, or the focus leaving it. Ignored once the edit has
  /// ended, so an Escape is not undone by the commit losing focus triggers.
  public func commitTabRename(of id: TerminalTab.ID, to title: String?) {
    guard renamingTabID == id else { return }
    renamingTabID = nil
    store.setCustomTitle(title, forTab: id)
  }

  /// The field's Escape: the title stays as it was.
  public func cancelRenamingTab() {
    renamingTabID = nil
  }

  /// The menu items name no column and split the focused one's active tab;
  /// a strip's own buttons name theirs, as New Tab does, and focus it.
  public func splitActivePane(_ axis: SplitAxis, in group: TabGroup.ID? = nil) {
    guard let worktree = worktreeReadyForShell(), let tab = tabToSplit(in: group, of: worktree)
    else { return }
    store.splitFocusedPane(of: tab.id, axis: axis)
    // The new pane takes focus in its tab, so its column must too, else the
    // keyboard stays in another column. Asked first, or autosave re-arms for nothing.
    if workspace.focusedGroup(in: worktree.id)?.id != tab.groupID {
      store.focusGroup(tab.groupID)
    }
    reconcileSessions(takingFocus: true)
  }

  /// A column named by a strip's own button, which has to be one of this
  /// worktree's, or the focused column's tab where none is named.
  private func tabToSplit(in group: TabGroup.ID?, of worktree: Worktree) -> TerminalTab? {
    guard let group else { return workspace.activeTab(in: worktree.id) }
    guard let column = workspace.group(group), column.worktreeID == worktree.id else { return nil }
    return workspace.activeTab(in: column)
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
