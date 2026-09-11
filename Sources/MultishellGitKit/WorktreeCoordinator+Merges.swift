import Foundation
import MultishellCore

/// Which branches have already landed on their project's default branch,
/// and what that branch is.
extension WorktreeCoordinator {
  /// The default branch, every local branch and each last commit, in one
  /// process. `nil` is a failed read, not a repository with no branches.
  public func scanBranches(
    of project: Project, defaultBranch override: String?
  ) async
    -> BranchScan?
  {
    guard let refs = await service.branchRefs(project) else { return nil }
    return BranchScan(refs: refs, defaultBranch: override)
  }

  /// Whether each of `branches` has landed, in the order of reads
  /// docs/design/merged-branch.md sets out. One absent keeps what it had.
  public func mergeStates(
    of branches: [String], in project: Project, scan: MergeScan
  ) async -> [String: WorktreeMergeState] {
    guard !branches.isEmpty else { return [:] }
    // A read that failed is not an answer. Taken as one, every branch would
    // be recorded as unmerged and stay that way until it next moved.
    guard let merged = await service.mergedBranches(into: scan.base.ref, in: project) else {
      return [:]
    }

    return await withTaskGroup(of: (String, WorktreeMergeState?).self) { group in
      var pending = branches.makeIterator()
      func startNext() {
        guard let branch = pending.next() else { return }
        group.addTask {
          (branch, await verdict(for: branch, merged: merged, scan: scan, in: project))
        }
      }
      for _ in 0..<Self.maxConcurrentStatuses { startNext() }

      var result: [String: WorktreeMergeState] = [:]
      for await (branch, state) in group {
        // A branch whose read failed is left out rather than answered for,
        // so the caller keeps the verdict it had and asks again next time.
        if let state { result[branch] = state }
        startNext()
      }
      return result
    }
  }

  /// `nil` where a read failed, so no verdict is reached rather than a wrong
  /// one recorded.
  private func verdict(
    for branch: String, merged: Set<String>, scan: MergeScan, in project: Project
  ) async -> WorktreeMergeState? {
    let base = scan.base.ref
    if merged.contains(branch) {
      guard let landed = await hasLanded(branch, in: project) else { return nil }
      return landed ? .merged(.ancestor, into: base) : .unmerged
    }
    guard let equivalent = await service.isPatchEquivalent(branch, against: base, in: project)
    else { return nil }
    if equivalent { return .merged(.patchEquivalent, into: base) }

    // A gone upstream is not enough alone; see docs/design/merged-branch.md.
    // `branch.<name>` config outlives its branch.
    guard scan.upstreamIsGone(branch) else { return .unmerged }
    guard let behind = await service.isBehind(branch, of: base, in: project) else { return nil }
    guard behind else { return .unmerged }
    guard let landed = await service.changesAreOnBase(branch, against: base, in: project)
    else { return nil }
    return landed ? .merged(.upstreamGone, into: base) : .unmerged
  }

  /// A branch the base can reach has landed or never left, the reflog
  /// separating them. `nil` only where the read failed.
  private func hasLanded(_ branch: String, in project: Project) async -> Bool? {
    await service.hasWorkOfItsOwn(branch, in: project)
  }

}
