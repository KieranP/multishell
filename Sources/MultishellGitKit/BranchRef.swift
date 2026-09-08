import Foundation

/// One row of `git for-each-ref` over `refs/heads` and `refs/remotes`: a
/// branch, where it points, and for a local branch the upstream it tracks.
///
/// The whole repository comes back in one process, which is what a merge
/// check starts from: without it every branch would cost a `rev-parse` of
/// its own before anything had been decided.
public struct BranchRef: Hashable, Sendable {
  /// `refs/heads/feat`, `refs/remotes/origin/main`.
  public let fullName: String
  public let tip: String
  /// The full name of the upstream a local branch tracks, whether or not
  /// that upstream still exists; `nil` for a branch that tracks nothing.
  public let upstream: String?
  /// The upstream is configured and no longer there: `git`'s `[gone]`.
  public let isUpstreamGone: Bool
  /// What this ref points at when it is symbolic, as
  /// `refs/remotes/origin/HEAD` is. Read here so the clone's own default
  /// branch costs no process of its own.
  public let symref: String?
  /// When the commit this ref points at was committed, which is what the
  /// sidebar's last-commit orders go by; `nil` where the row carried
  /// no date. Read here for the same reason as `symref`: the ref list is
  /// already being asked for, and a date per branch would otherwise cost a
  /// process each.
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

  /// The branch this ref stands for with no remote in front of it: both
  /// `refs/heads/main` and `refs/remotes/origin/main` are `main`. What a
  /// worktree sitting on the trunk has as its own branch, so the trunk's
  /// checkout is not badged as merged into itself.
  ///
  /// A branch name may hold slashes of its own, so only the remote's own
  /// first component is dropped, never more.
  public var branchName: String {
    guard isRemote else { return shortName }
    let short = shortName
    guard let slash = short.firstIndex(of: "/") else { return short }
    return String(short[short.index(after: slash)...])
  }
}
