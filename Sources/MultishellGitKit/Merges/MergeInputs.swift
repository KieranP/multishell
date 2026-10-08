/// What a merge check starts from: the default branch, and every local
/// branch's tip and upstream, all from the one `for-each-ref` a `BranchScan` reads.
public struct MergeInputs: Hashable, Sendable {
  public let defaultBranch: DefaultBranch
  /// Local branches by name; remote-tracking refs are dropped once the
  /// default branch has been resolved from them.
  let branches: [String: BranchRef]

  public func tip(of branch: String) -> String? { branches[branch]?.tip }

  public func upstreamIsGone(_ branch: String) -> Bool {
    branches[branch]?.upstreamIsGone ?? false
  }
}
