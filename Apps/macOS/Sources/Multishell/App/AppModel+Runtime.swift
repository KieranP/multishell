import AppKit
import MultishellCore
import MultishellGitKit
import SwiftUI

// MARK: - Reconciliation

extension AppModel {
  /// Brings the host in line with the store and focuses what should be
  /// focused. Every action that changes which terminals exist ends here.
  func sync() {
    let warm = warmWorktrees
    for failure in registry.reconcile(shouldBeLive: { warm.contains($0.worktreeID) }) {
      report(failure.error)
      store.closeSession(failure.sessionID)
    }
    registry.focusActiveSession()
    if let worktree = workspace.selectedWorktreeID, let tab = workspace.activeTab(in: worktree) {
      unseenActivity.subtract(tab.sessionIDs)
    }
  }

  func report(_ error: any Error) {
    presentedError = PresentedError(error)
  }
}

// MARK: - Git status

extension AppModel {
  /// Working-tree edits do not touch `.git`, so the watcher cannot see them.
  /// Poll instead, but only while the app is frontmost; a background app
  /// running `git status` across every worktree every few seconds is noise.
  func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        guard let self else { return }
        guard NSApp.isActive else { continue }
        await refreshStatuses()
      }
    }
  }

  func refreshStatuses() async {
    guard let worktrees else { return }
    let fresh = await worktrees.statuses(of: workspace.worktrees)
    if fresh != statuses { statuses = fresh }
    await refreshProjectsWhoseBranchMoved(fresh)
  }

  /// A `git checkout` in the main worktree touches `.git/HEAD`, which the
  /// watcher deliberately does not watch. The status poll sees the new
  /// branch name; when it disagrees with the sidebar, re-read that project.
  func refreshProjectsWhoseBranchMoved(_ fresh: [Worktree.ID: WorktreeStatus]) async {
    var drifted: Set<Project.ID> = []
    for worktree in workspace.worktrees {
      if let status = fresh[worktree.id], status.branch != worktree.branch {
        drifted.insert(worktree.projectID)
      }
    }
    for id in drifted {
      if let project = workspace.project(id) { await refresh(project) }
    }
  }

  func refreshStatus(of worktreeID: Worktree.ID) async {
    guard let worktrees, let worktree = workspace.worktree(worktreeID) else { return }
    let fresh = await worktrees.statuses(of: [worktree])
    if let status = fresh[worktreeID], status != statuses[worktreeID] {
      statuses[worktreeID] = status
    }
  }
}

// MARK: - Activity

extension AppModel {
  /// Activity in the focused tab is being watched; anywhere else it is
  /// remembered until that tab is shown.
  func noteActivity(in id: TerminalSession.ID) {
    // A prompt or a finished command in this worktree likely changed its
    // status, so look now rather than waiting for the next poll.
    if let session = workspace.session(id) {
      Task { await refreshStatus(of: session.worktreeID) }
    }
    if let worktree = workspace.selectedWorktreeID,
      let active = workspace.activeTab(in: worktree),
      active.root.contains(id)
    {
      return
    }
    unseenActivity.insert(id)
  }

  func hasUnseenActivity(_ tab: TerminalTab) -> Bool {
    !unseenActivity.isDisjoint(with: tab.sessionIDs)
  }

  func unseenActivityCount(in worktree: Worktree.ID) -> Int {
    workspace.sessions(in: worktree).filter { unseenActivity.contains($0.id) }.count
  }
}
