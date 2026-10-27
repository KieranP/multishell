import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

/// What a project's pull request host last answered, with the remotes the
/// rows are matched against. Runtime only; see Docs/design/services.md.
struct ProjectPullRequests: Equatable {
  let integration: ServiceIntegration
  /// The last list the host gave, kept through a failed read after it.
  var pullRequests: [PullRequest]
  var remotes: [GitRemote]
  /// Whether any read has answered; when is `RemoteState`'s, unobserved.
  var hasAnswered = false
  /// Why the latest read gave no answer, `nil` where it gave one.
  var failure: ServiceReadFailure?
  /// When the host last said the repository is not its own.
  var notHostedSince: Date?
}
