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
    guard let list = await git.branchRefs(project) else { return nil }
    return BranchScan(list, defaultBranchOverride: override)
  }

  public func deleteBranch(_ branch: String, in project: Project, force: Bool) async throws {
    do {
      try await git.deleteBranch(branch, in: project, force: force)
    } catch {
      let tip = await git.tip(ofBranch: branch, in: project)
      throw BranchDeletionFailure(branch: branch, tip: tip, underlying: error)
    }
  }

  /// `-D` only while the branch is at `tip`, what the refusal showed; moved since,
  /// it holds commits nobody was asked about, so `-d` judges it again.
  public func forceDeleteBranch(
    _ branch: String,
    atTip tip: String?,
    in project: Project,
  )
    async throws
  {
    var isWhereItWas = false
    if let tip { isWhereItWas = await git.tip(ofBranch: branch, in: project) == tip }
    try await deleteBranch(branch, in: project, force: isWhereItWas)
  }
}
