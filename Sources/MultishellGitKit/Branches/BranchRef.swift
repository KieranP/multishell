import Foundation

/// One row of `git for-each-ref` over `refs/heads` and `refs/remotes`. The
/// whole repository in one process, which is what a merge check starts from.
struct BranchRef: Hashable, Sendable {
  /// `refs/heads/feat`, `refs/remotes/origin/main`.
  let fullName: String
  let tip: String
  /// The full name of the upstream a local branch tracks, whether or not
  /// that upstream still exists; `nil` for a branch that tracks nothing.
  let upstream: String?
  /// The upstream is configured and no longer there: `git`'s `[gone]`.
  let isUpstreamGone: Bool
  /// What this ref points at when symbolic, as `refs/remotes/origin/HEAD`
  /// is. Read here so the default branch costs no process of its own.
  let symref: String?
  /// When the commit this ref points at was committed, for the sidebar's
  /// last-commit orders. Read here for the same reason as `symref`.
  let committedAt: Date?

  init(
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
  static let originHead = "refs/remotes/origin/HEAD"

  static let localPrefix = "refs/heads/"
  static let remotePrefix = "refs/remotes/"

  /// Full refname: a bare name reaches a tag of that name first, and git's
  /// ambiguity warning goes to stderr, which `runner.output` throws away.
  static func localRef(_ branch: String) -> String { localPrefix + branch }

  /// `refs/heads/feat` as `feat`, and any other name as it is.
  static func shortLocalName(_ ref: String) -> String {
    ref.hasPrefix(localPrefix) ? String(ref.dropFirst(localPrefix.count)) : ref
  }

  /// Local branches by short name, the first of any repeat kept.
  static func localBranchesByName(_ refs: [BranchRef]) -> [String: BranchRef] {
    Dictionary(
      refs.filter(\.isLocal).map { ($0.shortName, $0) }, uniquingKeysWith: { first, _ in first })
  }

  var isLocal: Bool { fullName.hasPrefix(Self.localPrefix) }
  var isRemote: Bool { fullName.hasPrefix(Self.remotePrefix) }

  /// What git would print for `%(refname:short)`: `feat`, `origin/main`.
  var shortName: String {
    if isRemote { return String(fullName.dropFirst(Self.remotePrefix.count)) }
    return Self.shortLocalName(fullName)
  }

  /// The branch with no remote in front of it, so the trunk's own checkout
  /// is not badged. Only the remote's first component is dropped.
  var branchName: String {
    guard isRemote else { return shortName }
    let short = shortName
    guard let slash = short.firstIndex(of: "/") else { return short }
    return String(short[short.index(after: slash)...])
  }
}
