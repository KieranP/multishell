import MultishellGitKit

/// What a project's branch scan found to measure against; a project no scan
/// has answered for has none of these.
enum DefaultBranchScan: Equatable, Sendable {
  case absent
  case found(DefaultBranch)

  var branch: DefaultBranch? {
    if case .found(let branch) = self { branch } else { nil }
  }
}
