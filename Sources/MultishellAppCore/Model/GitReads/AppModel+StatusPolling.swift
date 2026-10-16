import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Worktrees on a share are read every tick: FSEvents reports only what this
  /// Mac writes there.
  private static var tickInterval: Duration { .seconds(5) }
  /// File events report what changes on this Mac. Every twelfth tick is a
  /// full round for what none reports, such as an add's lock growing old.
  private static var ticksPerRound: Int { 12 }

  /// Only while frontmost: a background app running `git status` is noise.
  func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      var tick = 0
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.tickInterval)
        guard let self else { return }
        guard platform.isActive else { continue }
        tick += 1
        if tick.isMultiple(of: Self.ticksPerRound) {
          await pollRound()
        } else {
          await pollBetweenRounds()
        }
      }
    }
  }

  /// Worktrees on a share, and merge re-asks a budget left over, which waiting
  /// for the minute's round would spread over a quarter of an hour.
  func pollBetweenRounds() async {
    await pollWorktreesOnNetworkVolumes()
    if mergeReadLog.hasReadsLeftOver { await refreshBranchScans() }
  }

  func pollWorktreesOnNetworkVolumes() async {
    guard !worktreesOnNetworkVolumes.isEmpty else { return }
    await refreshStatuses { self.worktreesOnNetworkVolumes.contains($0.id) }
  }

  /// At launch, on a return to the front and once git is first found: every
  /// list git's records say changed, then every status and branch scan.
  func refreshAll() async {
    // A `.gitignore` edited while the app was behind raised an event nothing read.
    ignoreVerdicts = [:]
    await refreshProjectsIfChanged()
    await refreshStatuses()
    await refreshBranchScans()
  }

  /// The global excludes file sits outside every watched directory, so what
  /// git said it ignores is forgotten each round.
  func pollRound() async {
    ignoreVerdicts = [:]
    // Another machine adding a worktree on a share raises no event here.
    await refreshProjectsIfChanged()
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
