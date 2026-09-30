import MultishellCore

extension WorktreeCoordinator {
  public func deleteBranch(_ branch: String, force: Bool = false, in project: Project) async throws
  {
    do {
      try await git.deleteBranch(branch, force: force, in: project)
    } catch {
      throw BranchDeletionFailure(branch: branch, underlying: error)
    }
  }
}
