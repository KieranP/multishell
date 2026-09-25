import MultishellCore

/// Which branches have already landed on their project's default branch,
/// and what that branch is.
extension WorktreeCoordinator {
  /// The default branch, every local branch and each last commit, in one
  /// process. `nil` is a failed read, not a repository with no branches.
  public func scanBranches(
    of project: Project, defaultBranchOverride override: String?
  ) async
    -> BranchScan?
  {
    guard let refs = await git.branchRefs(project) else { return nil }
    return BranchScan(refs: refs, defaultBranchOverride: override)
  }

  /// Whether each of `branches` has landed and what each read cost, in
  /// merged-branch.md's order of reads. A nil verdict or none keeps what it had.
  public func readMerges(
    of branches: [String], in project: Project, inputs: MergeInputs
  ) async -> [String: MergeReading] {
    guard !branches.isEmpty else { return [:] }
    // A read that failed is not an answer. Taken as one, every branch would
    // be recorded as unmerged and stay that way until it next moved.
    guard let merged = await git.mergedBranches(into: inputs.base.fullName, in: project) else {
      return [:]
    }

    let readings = await branches.mapConcurrentlyUnordered(
      width: SharedGitReads.maxConcurrentReads
    ) { branch in
      await git.shared.mergeSlots.holding {
        let started = ContinuousClock.now
        let state = await verdict(for: branch, merged: merged, inputs: inputs, in: project)
        return (branch, MergeReading(state: state, took: started.duration(to: .now)))
      }
    }
    return Dictionary(readings, uniquingKeysWith: { _, last in last })
  }

  /// `nil` where a read failed, so no verdict is reached rather than a wrong
  /// one recorded.
  private func verdict(
    for branch: String, merged: Set<String>, inputs: MergeInputs, in project: Project
  ) async -> WorktreeMergeState? {
    let base = inputs.base.fullName
    let named = inputs.base.shortName
    if merged.contains(branch) {
      // A branch the base can reach has landed or never left, the reflog
      // separating them.
      guard let hasWork = await git.hasWorkOfItsOwn(branch, in: project) else { return nil }
      return hasWork ? .merged(.ancestor, into: named) : .unmerged
    }
    guard let equivalent = await git.isPatchEquivalent(branch, against: base, in: project)
    else { return nil }
    if equivalent { return .merged(.patchEquivalent, into: named) }

    // A gone upstream is not enough alone; see Docs/design/merged-branch.md.
    // `branch.<name>` config outlives its branch.
    guard inputs.upstreamIsGone(branch) else { return .unmerged }
    guard let behind = await git.isBehind(branch, of: base, in: project) else { return nil }
    guard behind else { return .unmerged }
    guard let landed = await git.changesAreOnBase(branch, against: base, in: project)
    else { return nil }
    return landed ? .merged(.upstreamGone, into: named) : .unmerged
  }
}
