import Foundation
import MultishellCore

/// Which branches have already landed on their project's default branch,
/// and what that branch is.
extension WorktreeCoordinator {
  /// Where the project's default branch points, what every local branch is,
  /// and when each was last committed to, in one process: `origin/HEAD` is
  /// a ref like any other, so the ref list carries it. See `BranchScan`.
  ///
  /// `override` is the project's `defaultBranch` setting, `nil` to detect.
  public func scanBranches(of project: Project, defaultBranch override: String?) async -> BranchScan
  {
    BranchScan(refs: await service.branchRefs(project), defaultBranch: override)
  }

  /// Whether each of `branches` has already landed on `scan.base`.
  ///
  /// One `git branch --merged` answers the merge-commit and fast-forward
  /// cases for all of them at once, though a branch it names still has to
  /// be told from one that has never left; see `hasLanded`. The branches it
  /// does not name get a `git cherry` for the rebase case, and only those
  /// still unaccounted for fall back to the upstream the scan already read.
  /// At most `maxConcurrentStatuses` run together, for the reason
  /// `statuses` bounds itself.
  ///
  /// The caller passes only the branches whose tips have moved since it
  /// last asked; a branch absent from the result keeps whatever it had.
  public func mergeStates(
    of branches: [String], in project: Project, scan: MergeScan
  ) async -> [String: WorktreeMergeState] {
    guard !branches.isEmpty else { return [:] }
    // A read that failed is not an answer. Taken as one, every branch would
    // be recorded as unmerged and stay that way until it next moved.
    guard let merged = await service.mergedBranches(into: scan.base.ref, in: project) else {
      return [:]
    }

    return await withTaskGroup(of: (String, WorktreeMergeState).self) { group in
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
        result[branch] = state
        startNext()
      }
      return result
    }
  }

  private func verdict(
    for branch: String, merged: Set<String>, scan: MergeScan, in project: Project
  ) async -> WorktreeMergeState {
    let base = scan.base.ref
    if merged.contains(branch) {
      return await hasLanded(branch, scan: scan, in: project)
        ? .merged(.ancestor, into: base) : .unmerged
    }
    if await service.isPatchEquivalent(branch, against: base, in: project) {
      return .merged(.patchEquivalent, into: base)
    }
    if scan.upstreamIsGone(branch) { return .merged(.upstreamGone, into: base) }
    return .unmerged
  }

  /// A branch the base can already reach has either landed or never left.
  /// `git worktree add -b` points a new branch at the commit it starts
  /// from, which makes it an ancestor of the trunk from the moment it
  /// exists, so ancestry alone would badge every worktree the user has just
  /// made. Its reflog is what separates them: a branch that has never moved
  /// since it was cut has one entry.
  ///
  /// Where there is no reflog to ask, the fresh branch still sitting on the
  /// base's own tip is the case worth catching, and the one a bare
  /// repository's worktrees fall into.
  private func hasLanded(_ branch: String, scan: MergeScan, in project: Project) async -> Bool {
    if let moved = await service.branchHasMoved(branch, in: project) { return moved }
    return scan.tip(of: branch) != scan.base.tip
  }

}
