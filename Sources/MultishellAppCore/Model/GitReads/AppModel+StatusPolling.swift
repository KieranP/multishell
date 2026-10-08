import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Working-tree edits do not touch `.git`, so poll instead, and only while
  /// frontmost: a background app running `git status` is noise.
  func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: self?.statusReadLog.pace.interval ?? .seconds(5))
        guard let self else { return }
        guard platform.isActive else { continue }
        await pollRound()
      }
    }
  }

  /// At launch, on a return to the front and once git is first found: every
  /// list git's records say changed, then every status and branch scan.
  func refreshAll() async {
    await refreshProjectsIfChanged()
    await refreshStatuses()
    await refreshBranchScans()
  }

  func pollRound() async {
    await refreshWorktreesWithUnfinishedAdds()
    await refreshStatuses()
    await refreshBranchScans()
    await refreshSharedSettingsIfChanged()
  }

  /// An add that died leaves git's mark with nothing in the records changing,
  /// so the list is read again each round, where the lock's age is judged.
  private func refreshWorktreesWithUnfinishedAdds() async {
    let marked = Set(workspace.worktrees.filter(\.isInitializing).map(\.projectID))
    await refreshWorktrees(ofProjects: marked.lazy.filter { !self.missingProjects.contains($0) })
  }
}
