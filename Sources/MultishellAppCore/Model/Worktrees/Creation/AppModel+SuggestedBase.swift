import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Where a new branch starts when nobody names a base: the sheet's first
  /// "Based on", and the command line's without `--from`.
  func suggestedBase(of project: Project) async -> String {
    let (local, remote) = await branches(of: project)
    return await suggestedBase(of: project, local: local, remote: remote)
  }

  /// The default branch, local before remote, as the picker lists it; the
  /// checkout's own branch only where there is none, as it may be other work.
  func suggestedBase(of project: Project, local: [String], remote: [String]) async -> String {
    // At launch the scan waits behind every status read, and the sheet can open first.
    if defaultBranchScans[project.id] == nil { await refreshBranchScan(of: project) }
    if let trunk = defaultBranch(of: project) {
      if local.contains(trunk.nameWithoutRemote) { return trunk.nameWithoutRemote }
      if remote.contains(trunk.shortName) { return trunk.shortName }
    }
    return await currentBranch(of: project)
  }

  func branches(of project: Project) async -> (local: [String], remote: [String]) {
    await coordinator?.git.branchNames(project) ?? ([], [])
  }

  private func currentBranch(of project: Project) async -> String {
    (try? await coordinator?.git.currentBranch(project)) ?? "HEAD"
  }
}
