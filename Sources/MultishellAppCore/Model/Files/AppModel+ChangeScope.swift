import MultishellCore
import MultishellGitKit

/// Modified or Branch: one choice for the panel's Changes list and every file
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

  /// Branch counts from the base, which a fetch moves and a launch resolves late.
  func noteDefaultBranchMoved(
    from previous: DefaultBranch?,
    to branch: DefaultBranch?,
    ofProject id: Project.ID,
  ) {
    if filesPanelWorktree?.projectID == id { schedulePanelBranchChangesRead() }
    guard workspace.changeScope == .branch else { return }
    // A tip moving keeps hidden tabs' dots; a base resolving or changing may not.
    let isNewBase = previous?.shortName != branch?.shortName
    noteFileTabsChanged(releasingDots: isNewBase) { tab in
      workspace.worktree(tab.worktreeID)?.projectID == id
    }
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
