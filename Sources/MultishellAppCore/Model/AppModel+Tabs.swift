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

  /// The selected worktree, when a shell may start in it: no create or
  /// remove is running there and its directory exists. `nil` otherwise, the
  /// missing-directory alert already raised.
  func worktreeReadyForShell() -> Worktree? {
    guard let worktree = workspace.selectedWorktree, !isBusy(worktree.id),
      directoryExists(of: worktree)
    else { return nil }
    return worktree
  }

  /// Cmd+T: the preferred agent when auto-start is on for this project,
  /// else a plain shell.
  public func newTab() {
    guard let worktree = worktreeReadyForShell() else { return }
    openFirstOrNewTab(in: worktree, on: .byUser)
    sync()
  }

  /// Cmd+Shift+T: always a plain shell, so one stays reachable when every
  /// New Tab starts an agent.
  public func newShellTab() {
    guard let worktree = worktreeReadyForShell() else { return }
    store.openTab(in: worktree.id)
    sync()
  }

  /// What a new tab is by default here: the agent if the project
  /// auto-starts one for this occasion, a shell otherwise. Also the first
  /// tab a worktree gets when it is selected or created.
  func openFirstOrNewTab(in worktree: Worktree, on opening: TabOpening) {
    if let project = project(of: worktree),
      autoStartsAgent(in: project, on: opening),
      let agentID = workspace.preferredAgentID(for: project)
    {
      store.openTab(in: worktree.id, title: agentDisplayName(agentID), agentID: agentID)
    } else {
      store.openTab(in: worktree.id)
    }
  }

  /// Whether a worktree with no tabs gets one for this reason: always when
  /// the tab was asked for, the create setting after a create, the select
  /// setting when the user turned to it. A worktree whose project has gone
  /// follows the global.
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

  /// The worktree's project with the repository's `.multishell.json`
  /// layered in, which is what these settings are read from: the file may
  /// say what a worktree here opens, and reading `project.settings` would
  /// pass over it.
  private func project(of worktree: Worktree) -> Project? {
    workspace.project(worktree.projectID).map { resolved($0) }
  }

  /// Whether that tab runs the agent rather than a shell. Only a create
  /// asks the create setting; a tab opened any other way, including the
  /// first tab of a worktree turned to, follows auto-start on tab open.
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

  /// Both closes. A close keystroke issued in a settings window closes that
  /// window instead, nothing happens with no tab on screen, and a pane whose
  /// agent reported Working asks before it goes; `PendingClose` says which
  /// shells each form would end.
  private func closeInShownTab(_ closing: (TerminalTab) -> PendingClose) {
    guard platform.workspaceWindowIsKey else { return platform.closeKeyWindow() }
    guard
      let worktree = workspace.selectedWorktreeID,
      let tab = workspace.activeTab(in: worktree)
    else { return }
    let close = closing(tab)
    if close.sessionIDs(in: tab).contains(where: { sessionStates[.session($0)] == .running }) {
      pendingClose = close
      return
    }
    perform(close)
  }

  /// The confirmed half of a close that found a working agent.
  public func confirmPendingClose() {
    guard let pending = pendingClose else { return }
    pendingClose = nil
    perform(pending)
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

  public func moveTab(_ id: TerminalTab.ID, before target: TerminalTab.ID) {
    store.moveTab(id, before: target)
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

  public func selectNextTab() { step(1) }
  public func selectPreviousTab() { step(-1) }

  func step(_ direction: Int) {
    guard
      let worktree = workspace.selectedWorktreeID,
      let current = workspace.activeTab(in: worktree),
      let next = direction > 0
        ? workspace.tab(after: current.id) : workspace.tab(before: current.id)
    else { return }
    activate(next)
  }
}
