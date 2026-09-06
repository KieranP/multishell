import AppKit
import MultishellCore
import MultishellGitKit
import SwiftUI

// MARK: - Tabs

extension AppModel {
  /// The project a worktree-scoped command should act on: the selected
  /// worktree's project, or the only project when nothing is selected yet.
  var activeProject: Project? {
    if let worktree = workspace.selectedWorktree {
      return workspace.project(worktree.projectID)
    }
    return workspace.projects.count == 1 ? workspace.projects.first : nil
  }

  /// Cmd+T: the preferred agent when auto-start is on for this project,
  /// else a plain shell.
  func newTab() {
    guard let worktree = workspace.selectedWorktree, !isBusy(worktree.id),
      directoryExists(of: worktree)
    else { return }
    openFirstOrNewTab(in: worktree)
    sync()
  }

  /// Cmd+Shift+T: always a plain shell, so one stays reachable when every
  /// New Tab starts an agent.
  func newShellTab() {
    guard let worktree = workspace.selectedWorktree, !isBusy(worktree.id),
      directoryExists(of: worktree)
    else { return }
    store.openTab(in: worktree.id)
    sync()
  }

  /// What a new tab is by default here: the agent if the project auto-starts
  /// one, a shell otherwise. Also the first tab a worktree gets when
  /// selected, which is what follows a create.
  func openFirstOrNewTab(in worktree: Worktree) {
    if let project = workspace.project(worktree.projectID),
      workspace.autoStartsAgent(for: project),
      let agentID = workspace.preferredAgentID(for: project)
    {
      store.openTab(in: worktree.id, title: agentDisplayName(agentID), agentID: agentID)
    } else {
      store.openTab(in: worktree.id)
    }
  }

  func closeActiveTab() {
    guard workspaceWindowIsKey else { return NSApp.keyWindow?.performClose(nil) ?? () }
    guard
      let worktree = workspace.selectedWorktreeID,
      let tab = workspace.activeTab(in: worktree)
    else { return }
    if tab.sessionIDs.contains(where: { sessionStates[.session($0)] == .running }) {
      pendingClose = .tab(tab.id)
      return
    }
    store.closeTab(tab.id)
    sync()
  }

  /// The confirmed half of a close that found a working agent.
  func confirmPendingClose() {
    guard let pending = pendingClose else { return }
    pendingClose = nil
    switch pending {
    case .pane(let id): store.closeSession(id)
    case .tab(let id): store.closeTab(id)
    }
    sync()
  }

  func activate(_ tab: TerminalTab) {
    store.activateTab(tab.id)
    sync()
  }

  func moveTab(_ id: TerminalTab.ID, before target: TerminalTab.ID) {
    store.moveTab(id, before: target)
  }

  func renameTab(_ id: TerminalTab.ID, to title: String?) {
    store.setCustomTitle(title, forTab: id)
  }

  func splitActivePane(_ axis: SplitAxis) {
    guard
      let worktree = workspace.selectedWorktree,
      let tab = workspace.activeTab(in: worktree.id),
      !isBusy(worktree.id),
      directoryExists(of: worktree)
    else { return }
    store.splitFocusedPane(of: tab.id, axis: axis)
    sync()
  }

  func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    store.setSplitWeights(weights, at: path, ofTab: tabID)
  }

  /// Cmd+W closes the focused pane; the tab goes with its last pane. A pane
  /// whose agent reported Working asks first.
  func closeActivePane() {
    guard workspaceWindowIsKey else { return NSApp.keyWindow?.performClose(nil) ?? () }
    guard
      let worktree = workspace.selectedWorktreeID,
      let tab = workspace.activeTab(in: worktree)
    else { return }
    if sessionStates[.session(tab.focusedSessionID)] == .running {
      pendingClose = .pane(tab.focusedSessionID)
      return
    }
    store.closeSession(tab.focusedSessionID)
    sync()
  }

  func selectNextTab() { step(1) }
  func selectPreviousTab() { step(-1) }

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
