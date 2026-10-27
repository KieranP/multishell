import Foundation
import MultishellCore

/// One row of `git for-each-ref` over `refs/heads` and `refs/remotes`. The
/// whole repository in one process, which is what a merge check starts from.
struct BranchRef: Hashable, Sendable {
  /// `refs/heads/feat`, `refs/remotes/origin/main`.
  let fullName: String
  let tip: String
  /// The upstream is configured and no longer there: `git`'s `[gone]`.
  let upstreamIsGone: Bool
  /// The remote-tracking ref this branch follows, `refs/remotes/origin/feat`.
  let upstreamRef: String?
  /// The remote that ref belongs to, and the branch's own name there, which
  /// is what a pull request and a CI run are known by.
  let upstreamRemote: String?
  let upstreamBranch: String?
  /// The remote its pushes go to, `branch.<name>.pushRemote` and
  /// `remote.pushDefault` resolved; one unlike `upstreamRemote` is a fork's.
  let pushRemote: String?
  /// What this ref points at when symbolic, as `refs/remotes/origin/HEAD`
  /// is. Read here so the default branch costs no process of its own.
  let symref: String?
  /// When the commit this ref points at was committed, for the sidebar's
  /// last-commit orders. Read here for the same reason as `symref`.
  let committedAt: Date?

  var isLocal: Bool { fullName.hasPrefix(RefName.localPrefix) }
  var isRemote: Bool { fullName.hasPrefix(RefName.remotePrefix) }

  /// `feat`, `origin/main`: `%(refname:lstrip=2)`, never `:short`'s `heads/feat`
  /// where a tag ties.
  var shortName: String {
    if isRemote { return String(fullName.dropFirst(RefName.remotePrefix.count)) }
    return RefName.shortLocal(fullName)
  }

  /// The branch with no remote in front of it, so the default branch's own
  /// checkout is not badged. Only the remote's first component is dropped.
  var nameWithoutRemote: String {
    guard isRemote else { return shortName }
    let short = shortName
    guard let slash = short.firstIndex(of: "/") else { return short }
    return String(short[short.index(after: slash)...])
  }

  init(
    fullName: String,
    tip: String,
    upstreamIsGone: Bool = false,
    upstreamRef: String? = nil,
    upstreamRemote: String? = nil,
    upstreamBranch: String? = nil,
    pushRemote: String? = nil,
    symref: String? = nil,
    committedAt: Date? = nil,
  ) {
    self.fullName = fullName
    self.tip = tip
    self.upstreamIsGone = upstreamIsGone
    self.upstreamRef = upstreamRef
    self.upstreamRemote = upstreamRemote
    self.upstreamBranch = upstreamBranch
    self.pushRemote = pushRemote
    self.symref = symref
    self.committedAt = committedAt
  }

  /// Local branches by short name, the first of any repeat kept.
  static func localBranchesByName(_ refs: [Self]) -> [String: Self] {
    Dictionary(
      keepingFirst:
        refs.filter(\.isLocal).map { ($0.shortName, $0) }
    )
  }
}
