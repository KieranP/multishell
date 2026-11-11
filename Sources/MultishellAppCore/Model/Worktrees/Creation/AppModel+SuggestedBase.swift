import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Where a new branch starts when nobody names a base: the sheet's first
  /// "Based on", and the command line's without `--from`.
  func suggestedBase(of project: Project) async -> String {
    await suggestedBase(of: project, among: await branches(of: project))
  }

  /// The default branch, local before remote; the checkout's own, maybe other work,
  /// only where there is none. Branches git could not list leave the scan's ref.
  func suggestedBase(
    of project: Project,
    among branches: (local: [String], remote: [String])?,
  ) async -> String {
    // At launch the scan waits behind every status read, and the sheet can open first.
    if defaultBranchScans[project.id] == nil { await refreshBranchScan(of: project) }
    if let trunk = defaultBranch(of: project) {
      guard let branches else { return trunk.shortName }
      if branches.local.contains(trunk.nameWithoutRemote) { return trunk.nameWithoutRemote }
      if branches.remote.contains(trunk.shortName) { return trunk.shortName }
    }
    return await currentBranch(of: project)
  }

  /// `nil` where git could not list them.
  func branches(of project: Project) async -> (local: [String], remote: [String])? {
    await coordinator?.git.branchNames(project)
  }

  private func currentBranch(of project: Project) async -> String {
    (try? await coordinator?.git.currentBranch(project)) ?? "HEAD"
  }
}
