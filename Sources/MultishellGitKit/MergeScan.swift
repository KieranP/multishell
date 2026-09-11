import Foundation

/// The two cheap reads a merge check starts from: the default branch, and
/// every local branch's tip and upstream. Two processes per repository.
public struct MergeScan: Hashable, Sendable {
  public let base: DefaultBranch
  /// Local branches by name; remote-tracking refs are dropped once the
  /// default branch has been resolved from them.
  public let branches: [String: BranchRef]

  public init(base: DefaultBranch, refs: [BranchRef]) {
    self.base = base
    self.branches = Dictionary(
      refs.filter(\.isLocal).map { ($0.shortName, $0) }, uniquingKeysWith: { first, _ in first })
  }

  public func tip(of branch: String) -> String? { branches[branch]?.tip }

  /// The branch tracks an upstream that is no longer on the remote.
  public func upstreamIsGone(_ branch: String) -> Bool {
    branches[branch]?.isUpstreamGone ?? false
  }
}
