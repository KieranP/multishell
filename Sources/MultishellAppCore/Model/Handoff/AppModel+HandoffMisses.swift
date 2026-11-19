import MultishellCore

/// Why a page's last Send sent nothing, said over its foot until the next pick or Send.
extension AppModel {
  public func handoffMiss(of worktree: Worktree, on page: ServicePage) -> String? {
    handoff.misses[worktree.id]?[page]
  }

  func noteHandoffMiss(_ text: String?, on page: ServicePage, in worktreeID: Worktree.ID) {
    var misses = handoff.misses[worktreeID] ?? [:]
    misses[page] = text
    setIfChanged(\.handoff.misses[worktreeID], misses.isEmpty ? nil : misses)
  }
}
