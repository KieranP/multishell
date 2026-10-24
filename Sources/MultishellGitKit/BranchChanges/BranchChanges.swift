/// What a worktree holds since its branch left the project's base branch,
/// committed or not, new files included; see Docs/design/files.md.
public struct BranchChanges: Hashable, Sendable {
  /// The base as git prints it short, `origin/main`.
  public let baseName: String
  /// The commit every change is counted from; `nil` where the branch shares
  /// no history with the base, which leaves nothing to count.
  public let mergeBase: String?
  public let changes: [StatusChange]
  private let kinds: ChangeKinds
  public let insertions: Int
  public let deletions: Int

  init(baseName: String, mergeBase: String?, changes: [StatusChange]) {
    self.baseName = baseName
    self.mergeBase = mergeBase
    self.changes = changes
    kinds = ChangeKinds(changes)
    let counts = LineCounts(summing: changes.map(\.lines))
    insertions = counts.insertions
    deletions = counts.deletions
  }

  /// One path's kind, looked up per file tab render.
  public func kind(of path: String) -> StatusChange.Kind? { kinds[path] }
}
