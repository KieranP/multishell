import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

/// A pull request host or CI provider per integration whose tool detection
/// found. Rebuilt with git once the login shell's PATH is known.
struct ServiceConnections: Sendable {
  static let empty = Self(pullRequestHosts: [:], ciProviders: [:])

  var pullRequestHosts: [ServiceIntegration: any PullRequestHost]
  var ciProviders: [ServiceIntegration: any CIProvider]

  init(
    pullRequestHosts: [ServiceIntegration: any PullRequestHost],
    ciProviders: [ServiceIntegration: any CIProvider],
  ) {
    self.pullRequestHosts = pullRequestHosts
    self.ciProviders = ciProviders
  }

  /// Every run times into git's log, so Debug Info counts them beside it.
  init(
    detection: ServiceToolDetection,
    searchPath: String?,
    runLog: GitRunLog,
    loginVariables: [String: String],
  ) {
    self = .empty
    for (integration, executable) in detection.found {
      switch integration {
      case .circleCI:
        ciProviders[integration] = CircleCIProvider(
          executable: executable,
          searchPath: searchPath,
          runLog: runLog,
          loginVariables: loginVariables,
        )

      case .gitHub:
        pullRequestHosts[integration] = GitHubHost(
          executable: executable,
          searchPath: searchPath,
          runLog: runLog,
          loginVariables: loginVariables,
        )
      }
    }
  }
}
