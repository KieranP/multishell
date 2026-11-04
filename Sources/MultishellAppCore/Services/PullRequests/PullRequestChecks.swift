import MultishellServices

/// The checks on a pull request's head, read while the panel shows it.
/// Runtime only; see Docs/design/services.md.
struct PullRequestChecks: Equatable, Sendable {
  let pullRequestNumber: Int
  /// The head they were last asked about, answered or not: a push moves it,
  /// and they are read again.
  var headCommit: String
  /// The last list read, kept through a failed read after it; `nil` until one
  /// answers.
  var checks: [PullRequestCheck]?
  var failure: ServiceReadFailure?
}
