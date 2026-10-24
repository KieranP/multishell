import MultishellCore
import MultishellGitKit

/// Modified or Branch: one choice for the panel's Git list and every file
/// tab, which count a change against the same thing; see Docs/design/files.md.
extension AppModel {
  /// The panel's switch and every file tab's, kept for the next launch.
  public func setChangeScope(_ scope: ChangeScope) {
    guard workspace.changeScope != scope else { return }
    store.setChangeScope(scope)
    noteFileTabsChanged(releasingDots: true, where: offersChangeScopeSwitch(for:))
    forgetBranchChangesUnlessListed()
    schedulePanelBranchChangesRead()
  }

  /// Only where the project has a base branch, a tab there counting from `HEAD`
  /// whatever the choice.
  public func offersChangeScopeSwitch(for tab: FileTab) -> Bool {
    defaultBranch(ofWorktree: tab.worktreeID) != nil
  }

  /// What a file tab in the worktree counts from in place of `HEAD`: its
  /// project's base branch, under Branch.
  func fileTabBase(in id: Worktree.ID) -> DefaultBranch? {
    workspace.changeScope == .branch ? defaultBranch(ofWorktree: id) : nil
  }
}
