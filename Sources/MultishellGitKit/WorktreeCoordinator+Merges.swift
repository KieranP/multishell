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
  ///
  /// `nil` where the ref read failed, which is not a repository with no
  /// branches; see `WorktreeService.branchRefs`.
  public func scanBranches(
    of project: Project, defaultBranch override: String?
  ) async
    -> BranchScan?
  {
    guard let refs = await service.branchRefs(project) else { return nil }
    return BranchScan(refs: refs, defaultBranch: override)
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

    // A gone upstream is not enough on its own, for two reasons.
    //
    // `branch.<name>` config outlives the branch it names, so a branch cut
    // under a name used before starts life tracking a remote branch this
    // clone has never had, and git calls that `[gone]` too; work that landed
    // on the base left a commit there, so a branch the base has nothing to
    // add to has landed nothing.
    //
    // And the badge hides while a worktree holds work that is only there,
    // which for a gone upstream `git status` cannot see: there is no
    // upstream left to be ahead of. So the content is asked for instead.
    guard scan.upstreamIsGone(branch) else { return .unmerged }
    guard let behind = await service.isBehind(branch, of: base, in: project) else { return nil }
    guard behind else { return .unmerged }
    guard let landed = await service.changesAreOnBase(branch, against: base, in: project)
    else { return nil }
    return landed ? .merged(.upstreamGone, into: base) : .unmerged
  }

  /// A branch the base can already reach has either landed or never left.
  /// `git worktree add -b` points a new branch at the commit it starts
  /// from, which makes it an ancestor of the trunk from the moment it
  /// exists, and a `git pull` in a worktree cut before the trunk moved
  /// fast-forwards it onto commits it was handed and leaves it one. So
  /// ancestry alone would badge both. What the branch's reflog says was done
  /// to it is what separates them; see `ReflogWorkParser`.
  ///
  /// Where there is no reflog to ask, nothing separates the two, so nothing
  /// is claimed. A bare repository logs no branch creation, so its worktrees
  /// fall in here until their first commit, which it does log; guessing from
  /// the tips instead badges every one of them that was cut from anywhere but
  /// the trunk's own tip. The cost is a branch whose reflog has expired losing
  /// a badge it had earned, which is a badge not drawn rather than a worktree
  /// wrongly said to be finished with.
  ///
  /// `nil` only where the read itself failed, which is not that answer: git
  /// says "no reflog" with an empty answer and a success.
  private func hasLanded(_ branch: String, in project: Project) async -> Bool? {
    await service.hasWorkOfItsOwn(branch, in: project)
  }

}
