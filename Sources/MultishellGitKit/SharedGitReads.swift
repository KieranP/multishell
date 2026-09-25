/// What every git layer a launch builds shares, git itself changing under
/// it: the untracked counts, and one width for every project's merge reads.
struct SharedGitReads: Sendable {
  /// How many merge reads run at once across every project, and how many
  /// status reads one round runs; see Docs/design/merged-branch.md.
  static let maxConcurrentReads = 8

  let untrackedMemo = UntrackedLineMemo()
  let mergeSlots = ConcurrencySlots(width: maxConcurrentReads)
}
