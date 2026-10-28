import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A scan's upstreams, unless a newer scan began while its reflog reads ran.
  func recordUpstreams(
    _ upstreams: [String: BranchUpstream],
    of project: Project,
    fromScan scanNumber: Int,
  ) async {
    let ownUpstreams = await upstreamsOfTheirOwn(upstreams, of: project)
    guard remoteState.branchScansBegun[project.id] == scanNumber else { return }
    recordBranchUpstreams(ownUpstreams, of: project.id)
  }

  /// A worktree's branch following the remote one it was made from, under
  /// another name, follows someone else's; see Docs/design/services.md.
  private func upstreamsOfTheirOwn(
    _ upstreams: [String: BranchUpstream],
    of project: Project,
  ) async -> [String: BranchUpstream] {
    let worktrees = workspace.worktrees(of: project.id)
    let checkedOut = Set(worktrees.compactMap(\.branch))
    // Only a worktree where the app makes them: one a user made follows by choice.
    let folder = effectiveWorktreeSettings(for: project).worktreeContainer(for: project).path + "/"
    let madeByTheApp = Set(
      worktrees.filter { $0.path.standardizedFileURL.path.hasPrefix(folder) }.compactMap(\.branch)
    )
    let trunk = defaultBranchName(of: project)
    remoteState.branchStartPoints[project.id] = remoteState.branchStartPoints[project.id]?
      .filter { checkedOut.contains($0.key) }
    var kept = upstreams
    for (branch, upstream) in upstreams
    where madeByTheApp.contains(branch) && upstream.branch != branch && upstream.branch != trunk {
      let madeFrom = await startPoint(ofBranch: branch, in: project)
      if madeFrom == "\(upstream.remote)/\(upstream.branch)" { kept[branch] = nil }
    }
    return kept
  }

  /// Read once per branch while a worktree has it out: what it was made from
  /// does not change. A read git failed is not kept, so the next scan asks.
  private func startPoint(ofBranch branch: String, in project: Project) async -> String? {
    if let known = remoteState.branchStartPoints[project.id]?[branch] { return known }
    guard let git = coordinator?.git else { return nil }
    do {
      let madeFrom = try await git.startPoint(ofBranch: branch, in: project)
      remoteState.branchStartPoints[project.id, default: [:]][branch] = .some(madeFrom)
      return madeFrom
    } catch {
      return nil
    }
  }
}
