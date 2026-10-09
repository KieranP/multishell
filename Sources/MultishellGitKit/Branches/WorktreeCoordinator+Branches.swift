import MultishellCore

extension WorktreeCoordinator {
  /// The default branch, every local branch and each last commit, in one
  /// process. `nil` is a failed read, not a repository with no branches.
  public func scanBranches(
    of project: Project,
    defaultBranchOverride override: String?,
  ) async
    -> BranchScan?
  {
    guard let refs = await git.branchRefs(project) else { return nil }
    return BranchScan(refs: refs, defaultBranchOverride: override)
  }

  public func deleteBranch(_ branch: String, in project: Project, force: Bool = false) async throws
  {
    do {
      try await git.deleteBranch(branch, in: project, force: force)
    } catch {
      throw BranchDeletionFailure(branch: branch, underlying: error)
    }
  }
}
