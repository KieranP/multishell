import MultishellCore

extension AppModel {
  /// A worktree menu's New Shell Tab: that worktree selected first, so the tab
  /// opens where it was asked for, and nothing opened where it cannot be.
  public func newShellTab(selecting worktree: Worktree) {
    guard select(worktree, openingFirstTab: .never) else { return }
    newShellTab()
  }

  /// The same for New Agent Tab, starting the agent the project prefers.
  public func newAgentTab(selecting worktree: Worktree) {
    guard select(worktree, openingFirstTab: .never) else { return }
    newAgentTab()
  }
}
