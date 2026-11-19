import MultishellServices

/// The unresolved review threads of the panel worktree's open pull request,
/// read while its page shows. Runtime only; see Docs/design/services/send-feedback.md.
struct PullRequestThreads: Equatable, Sendable {
  let pullRequestNumber: Int
  /// The last read's, kept through a failed read after it; `nil` until one answers.
  var threads: [PullRequestThread]?
  var failure: ServiceReadFailure?
}
