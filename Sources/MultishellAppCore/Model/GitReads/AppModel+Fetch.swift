import MultishellCore

extension AppModel {
  /// Whether a fetch is running on this project: its row spins, and the
  /// menu item that started it is disabled until it ends.
  public func isFetching(_ project: Project) -> Bool {
    fetchingProjects.contains(project.id)
  }

  /// The menus' Fetch, the one git call that talks to a network and only on
  /// a click. Marked for the whole of it, re-reads included.
  public func fetch(_ project: Project) async {
    guard let coordinator, fetchingProjects.insert(project.id).inserted else { return }
    defer { fetchingProjects.remove(project.id) }
    do {
      try await coordinator.git.fetch(project)
    } catch {
      present(error)
      return
    }
    await refreshWorktrees(of: project)
    await refreshStatuses()
    await refreshMergeStates(of: project)
  }
}
