import MultishellCore
import MultishellGitKit

/// What an All changes tab says with no file to show, as the mockup's empty
/// state does; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// Under Branch, the base it counts from; under Modified, the worktree, and
  /// what Branch would show where the project has a base.
  public func allChangesEmptyText(of tab: AllChangesTab) -> PanelPageEmptyText {
    if listsOnlyNestedRepositories(tab) {
      return PanelPageEmptyText(
        title: t("all-changes.only-nested-repositories"),
        detail: t("all-changes.only-nested-repositories-hint"),
      )
    }
    if let base = fileTabBase(in: tab.worktreeID) {
      return PanelPageEmptyText(
        title: t("files-panel.no-branch-changes", base.shortName),
        detail: nil,
      )
    }
    let name = workspace.worktree(tab.worktreeID).map(workspace.displayName(of:)) ?? ""
    return PanelPageEmptyText(
      title: t("all-changes.no-uncommitted", name),
      detail: defaultBranch(ofWorktree: tab.worktreeID).map { branch in
        t("all-changes.branch-hint", branch.shortName)
      },
    )
  }

  /// Changes lists a nested repository, a submodule's folder or one git leaves
  /// untracked with a trailing `/`, which the tab's read leaves out.
  private func listsOnlyNestedRepositories(_ tab: AllChangesTab) -> Bool {
    guard let reading = allChangesReadings[tab.id] else { return false }
    if !reading.listed.isEmpty { return true }
    let listed = allChangesListedChanges(of: tab.worktreeID) ?? []
    return !listed.isEmpty && listed.allSatisfy { $0.path.hasSuffix("/") }
  }

  /// The Branch read that failed, said in place of the wait for a list that will
  /// not come; `nil` while there is none.
  public func allChangesReadFailure(of tab: AllChangesTab) -> PanelPageEmptyText? {
    guard let base = fileTabBase(in: tab.worktreeID),
      failedBranchReads[tab.worktreeID] == base.shortName
    else { return nil }
    return PanelPageEmptyText(
      title: t("files-panel.branch-unreadable", base.shortName),
      detail: nil,
    )
  }

  /// Show Branch, under Modified where the project has a base to count from.
  public func offersBranchScope(onEmpty tab: AllChangesTab) -> Bool {
    workspace.changeScope == .modified && defaultBranch(ofWorktree: tab.worktreeID) != nil
  }
}
