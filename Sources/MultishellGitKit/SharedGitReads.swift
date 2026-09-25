/// What every git layer a launch builds shares, git itself changing under
/// it: the untracked counts, and one width for every project's merge reads.
struct SharedGitReads: Sendable {
  /// How many status reads, and how many merge reads, run at once; see
  /// Docs/design/merged-branch.md.
  static let maxConcurrentReads = 8

  let untrackedMemo = UntrackedLineMemo()
  let mergeSlots = GitSlots(width: maxConcurrentReads)
}
