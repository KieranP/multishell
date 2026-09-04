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

  func newTab() {
    guard let worktree = workspace.selectedWorktree, directoryExists(of: worktree) else { return }
    store.openTab(in: worktree.id)
    sync()
  }

  func closeActiveTab() {
    guard workspaceWindowIsKey else { return NSApp.keyWindow?.performClose(nil) ?? () }
    guard
      let worktree = workspace.selectedWorktreeID,
      let tab = workspace.activeTab(in: worktree)
    else { return }
    store.closeTab(tab.id)
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
      directoryExists(of: worktree)
    else { return }
    store.splitFocusedPane(of: tab.id, axis: axis)
    sync()
  }

  func setSplitWeights(_ weights: [Double], at path: [Int], ofTab tabID: TerminalTab.ID) {
    store.setSplitWeights(weights, at: path, ofTab: tabID)
  }

  /// Cmd+W closes the focused pane; the tab goes with its last pane.
  func closeActivePane() {
    guard workspaceWindowIsKey else { return NSApp.keyWindow?.performClose(nil) ?? () }
    guard
      let worktree = workspace.selectedWorktreeID,
      let tab = workspace.activeTab(in: worktree)
    else { return }
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
