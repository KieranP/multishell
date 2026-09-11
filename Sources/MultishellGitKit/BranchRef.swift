import Foundation

/// One row of `git for-each-ref` over `refs/heads` and `refs/remotes`. The
/// whole repository in one process, which is what a merge check starts from.
public struct BranchRef: Hashable, Sendable {
  /// `refs/heads/feat`, `refs/remotes/origin/main`.
  public let fullName: String
  public let tip: String
  /// The full name of the upstream a local branch tracks, whether or not
  /// that upstream still exists; `nil` for a branch that tracks nothing.
  public let upstream: String?
  /// The upstream is configured and no longer there: `git`'s `[gone]`.
  public let isUpstreamGone: Bool
  /// What this ref points at when symbolic, as `refs/remotes/origin/HEAD`
  /// is. Read here so the default branch costs no process of its own.
  public let symref: String?
  /// When the commit this ref points at was committed, for the sidebar's
  /// last-commit orders. Read here for the same reason as `symref`.
  public let committedAt: Date?

  public init(
    fullName: String, tip: String, upstream: String? = nil, isUpstreamGone: Bool = false,
    symref: String? = nil, committedAt: Date? = nil
  ) {
    self.fullName = fullName
    self.tip = tip
    self.upstream = upstream
    self.isUpstreamGone = isUpstreamGone
    self.symref = symref
    self.committedAt = committedAt
  }

  /// The ref a clone records as the remote's default branch.
  public static let originHead = "refs/remotes/origin/HEAD"

  public static let localPrefix = "refs/heads/"
  public static let remotePrefix = "refs/remotes/"

  public var isLocal: Bool { fullName.hasPrefix(Self.localPrefix) }
  public var isRemote: Bool { fullName.hasPrefix(Self.remotePrefix) }

  /// What git would print for `%(refname:short)`: `feat`, `origin/main`.
  public var shortName: String {
    if isLocal { return String(fullName.dropFirst(Self.localPrefix.count)) }
    if isRemote { return String(fullName.dropFirst(Self.remotePrefix.count)) }
    return fullName
  }

  /// The branch with no remote in front of it, so the trunk's own checkout
  /// is not badged. Only the remote's first component is dropped.
  public var branchName: String {
    guard isRemote else { return shortName }
    let short = shortName
    guard let slash = short.firstIndex(of: "/") else { return short }
    return String(short[short.index(after: slash)...])
  }
}
