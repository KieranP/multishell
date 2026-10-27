import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Whether a fetch is running on this project: its row spins, and the
  /// menu item that started it is disabled until it ends.
  public func isFetching(_ project: Project) -> Bool {
    remoteState.fetchingProjects.contains(project.id)
  }

  /// The menus' Fetch, the one git call that talks to a network and only on
  /// a click. Marked for the whole of it, re-reads included.
  public func fetch(_ project: Project) async {
    guard let coordinator, remoteState.fetchingProjects.insert(project.id).inserted else { return }
    defer { remoteState.fetchingProjects.remove(project.id) }
    // Before the network call: a scan the watcher runs during it records what
    // moved, and has scheduled the read already.
    let upstreamsBefore = upstreams(ofProject: project.id)
    do {
      try await coordinator.git.fetch(project)
    } catch {
      present(error)
      return
    }
    await refreshWorktrees(of: project)
    await refreshBadges(ofProject: project.id)
    // An upstream moved or added in a project asked before has its settled read
    // scheduled already; a worktree that only went schedules nothing.
    let moved = upstreams(ofProject: project.id).contains { upstreamsBefore[$0.key] != $0.value }
    let hasScheduledRead = moved && remoteState.readLog.hasAsked(project.id)
    if !hasScheduledRead { scheduleServicesRead(of: project.id) }
  }

  private func upstreams(ofProject id: Project.ID) -> [Worktree.ID: BranchUpstream] {
    let ids = Set(workspace.worktrees(of: id).map(\.id))
    return remoteState.upstreams.filter { ids.contains($0.key) }
  }
}
