/// The remote branch a local branch is set to follow, by the names the
/// remote knows it by: what a pull request and a CI run are filed under.
public struct BranchUpstream: Hashable, Sendable {
  /// `origin`.
  public let remote: String
  /// The branch's name on the remote, which need not be its local one.
  public let branch: String
  /// Where the remote-tracking ref points, `nil` where it has gone. It moves
  /// on a push, a fetch and a pull, which re-reads the pull requests.
  public let tip: String?

  /// The same upstream where the remote no longer has the branch.
  public var goneFromRemote: Self {
    Self(remote: remote, branch: branch, tip: nil)
  }
}
