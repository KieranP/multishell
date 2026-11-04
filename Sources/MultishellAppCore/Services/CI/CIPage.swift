import MultishellServices

/// What the panel's CI page shows for a worktree.
public enum CIPage: Equatable, Sendable {
  /// Pushed, and no run has been found.
  case noRuns(branch: String)
  /// A detached head or a bare repository: no branch, so no runs to find.
  case notApplicable
  /// No checkout holds the provider's configuration file.
  case notConfigured
  /// The provider said the repository is not one it follows.
  case notHosted(provider: String)
  /// Nobody pushed the branch, so nothing has run it.
  case notPushed(branch: String)
  /// No runs have been read yet: still asking, or the read failed, and why.
  case notRead(problem: String?)
  /// The newest run, from the page's history where read, else the row's.
  case run(CIRun)
  case turnedOff
}
