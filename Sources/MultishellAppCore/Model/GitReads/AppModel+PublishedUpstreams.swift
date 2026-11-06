import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A branch published under its own name where git tracks another counts
  /// only once it held that tip, else what it follows; see services/branch-matching.md.
  func upstreamsPublishedByTheirBranches(
    _ upstreams: [String: BranchUpstream],
    fallbacks: [String: BranchUpstream?],
    branchTips: [String: String],
    of project: Project,
  ) async -> [String: BranchUpstream] {
    let checkedOut = Set(workspace.worktrees(of: project.id).compactMap(\.branch))
    remoteState.publishedTipChecks[project.id] = remoteState.publishedTipChecks[project.id]?
      .filter { checkedOut.contains($0.key) }
    let trunk = defaultBranchName(of: project)
    var kept = upstreams
    // No branch reuses the trunk's name, so its remote one is its own.
    for (branch, fallback) in fallbacks where checkedOut.contains(branch) && branch != trunk {
      guard let remoteTip = upstreams[branch]?.tip else { continue }
      let isPublished = await countsAsPublished(
        remoteTip,
        byBranch: branch,
        at: branchTips[branch],
        in: project,
      )
      if !isPublished { kept[branch] = fallback }
    }
    return kept
  }

  /// Asked again only once either tip moves: a reflog grows only as its branch does.
  private func countsAsPublished(
    _ remoteTip: String,
    byBranch branch: String,
    at branchTip: String?,
    in project: Project,
  ) async -> Bool {
    if let known = remoteState.publishedTipChecks[project.id]?[branch],
      known.remoteTip == remoteTip, known.branchTip == branchTip
    {
      return known.countsAsPublished
    }
    // A failed read is not a verdict, and no reflog says nothing: the scan's stands.
    guard let git = coordinator?.git,
      let held = try? await git.tipsHeld(byBranch: branch, in: project)
    else { return true }
    let countsAsPublished = held.isEmpty || held.contains(remoteTip)
    remoteState.publishedTipChecks[project.id, default: [:]][branch] = PublishedTipCheck(
      branchTip: branchTip,
      remoteTip: remoteTip,
      countsAsPublished: countsAsPublished,
    )
    return countsAsPublished
  }
}
