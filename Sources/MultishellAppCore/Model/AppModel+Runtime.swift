import Foundation
import MultishellCore
import MultishellGitKit

// MARK: - Reconciliation

extension AppModel {
  /// Brings the host in line with the store and focuses what should be
  /// focused. Every action that changes which terminals exist ends here.
  public func sync() {
    let warm = warmWorktrees
    let failures = registry.reconcile(
      shouldBeLive: { warm.contains($0.worktreeID) }, prepare: { prepared($0) })
    for failure in failures {
      report(failure.error)
      store.closeSession(failure.sessionID)
    }
    registry.focusActiveSession()
    pruneStates()
    markShownTabSeen()
  }

  /// Done clears for what is on screen: the active tab's panes, and the
  /// selected worktree's own entry.
  func markShownTabSeen() {
    guard let worktree = workspace.selectedWorktreeID else { return }
    let shown = workspace.activeTab(in: worktree)?.sessionIDs ?? []
    mutateStates { $0.markSeen(sessions: shown, worktree: worktree) }
  }

  public func report(_ error: any Error) {
    presentedError = PresentedError(error)
  }
}

// MARK: - Filesystem

extension AppModel {
  /// For the reads the polling paths make: whether a project directory is
  /// there, the record files under `.git`, the directories to watch. On a
  /// local disk each is microseconds; on a network volume that has gone
  /// away each blocks until the mount times out, which must not be on the
  /// main thread every five seconds.
  nonisolated static func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
    await Task.detached(priority: .utility) { work() }.value
  }
}

// MARK: - Git status

extension AppModel {
  /// Working-tree edits do not touch `.git`, so the watcher cannot see them.
  /// Poll instead, but only while the app is frontmost; a background app
  /// running `git status` across every worktree every few seconds is noise.
  public func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        guard let self else { return }
        guard platform.isActive else { continue }
        await refreshStatuses()
        await refreshMergeStates()
        await refreshChangedSharedSettings()
      }
    }
  }

  /// A worktree whose read failed this round keeps its last badge rather
  /// than blinking off for five seconds; one whose worktree is gone loses it.
  public func refreshStatuses() async {
    guard let worktrees else { return }
    let known = Set(workspace.worktrees.map(\.id))
    let fresh = await worktrees.statuses(of: workspace.worktrees)
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh) { _, new in new }
    if merged != statuses { statuses = merged }
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

  public func refreshStatus(of worktreeID: Worktree.ID) async {
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
    // status, so look soon rather than waiting for the next poll.
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    mutateStates { $0.noteActivity(in: id, isShown: isShown(id)) }
  }

  /// One command at a prompt raises several events in a row (title before,
  /// command finished, title after), and each would otherwise spawn its own
  /// `git status`. The burst becomes one run, shortly after the last event.
  func scheduleStatusRefresh(of worktreeID: Worktree.ID) {
    pendingStatusRefreshes[worktreeID]?.cancel()
    pendingStatusRefreshes[worktreeID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self else { return }
      pendingStatusRefreshes[worktreeID] = nil
      await refreshStatus(of: worktreeID)
    }
  }

  func noteTitle(_ title: String, of id: TerminalSession.ID) {
    if sessionTitles[id] != title { sessionTitles[id] = title }
  }

  /// What the tab strip shows: the user's name, else what the shell last
  /// reported, else the tab's starting title.
  public func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }
}
