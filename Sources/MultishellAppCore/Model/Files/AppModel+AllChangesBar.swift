import MultishellCore
import MultishellGitKit

/// What the All changes tab's bar offers, as a file tab's bar does.
extension AppModel {
  /// Only where the project has a base branch, the tab counting from `HEAD`
  /// otherwise whatever the choice.
  public func offersChangeScopeSwitch(for tab: AllChangesTab) -> Bool {
    defaultBranch(ofWorktree: tab.worktreeID) != nil
  }

  /// The base the tab counts from under Branch, which an empty tab names.
  public func allChangesBaseName(of tab: AllChangesTab) -> String? {
    fileTabBase(in: tab.worktreeID)?.shortName
  }
}
