import MultishellCore

/// Why a page's last Send sent nothing, said over its foot until the next pick or Send.
extension AppModel {
  public func handoffMiss(of worktree: Worktree, on page: ServicePage) -> String? {
    handoff.misses[worktree.id]?[page]
  }

  /// Nothing for a worktree removed during a Send's reads: a worktree made again
  /// at its path, its id, would show the note.
  func noteHandoffMiss(_ text: String?, on page: ServicePage, in worktreeID: Worktree.ID) {
    guard workspace.worktree(worktreeID) != nil else { return }
    var misses = handoff.misses[worktreeID] ?? [:]
    misses[page] = text
    setIfChanged(\.handoff.misses[worktreeID], misses.isEmpty ? nil : misses)
  }
}
