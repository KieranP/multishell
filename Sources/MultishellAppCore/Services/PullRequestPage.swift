import MultishellServices

/// What the panel's pull request page shows for a worktree.
public enum PullRequestPage: Equatable, Sendable {
  /// The branch has none; Create Pull Request pushes first where the remote
  /// lacks it.
  case noPullRequest(branch: String, isPushed: Bool)
  /// The trunk, a detached head or a bare repository, none of which has one.
  case notApplicable
  /// The host's own word, kept from its last read.
  case notHosted
  /// No list has been read yet: still asking, or the read failed, and why.
  case notRead(problem: String?)
  case pullRequest(PullRequest)
  /// No host is turned on for the project.
  case turnedOff
}
