import Foundation
import MultishellCore
import MultishellGitKit
import MultishellServices

/// What a project's CI provider last answered: the newest run of each branch,
/// by its name on the remote. Runtime only; see Docs/design/services.md.
struct ProjectCIRuns: Equatable {
  let integration: ServiceIntegration
  /// Whether a checkout holds the provider's configuration file; without it
  /// nothing is asked and no row shows a run.
  var isConfigured = true
  /// The project's remotes, whose URLs say which repository a branch is in.
  var remotes: [GitRemote] = []
  /// The last runs read, kept through a failed read after them.
  var runsByBranch: [String: CIRun]
  /// The shown branches the recent runs left out, by their name on the remote.
  var lookups: [String: BranchRunLookup] = [:]
  /// Whether any read has answered; when is `RemoteState`'s, unobserved.
  var hasAnswered = false
  var failure: ServiceReadFailure?
  /// Branches asked alone whose lookup failed, said on their rows alone.
  var branchFailures: [String: ServiceReadFailure] = [:]
  /// When the provider last said the repository is not its own.
  var notHostedSince: Date?

  /// The runs before it stand, but not for a provider that disowns the
  /// repository: as the host's, it has no runs of it.
  mutating func recordFailure(_ failure: ServiceReadFailure) {
    self.failure = failure
    guard failure == .notHosted else { return }
    notHostedSince = .now
    runsByBranch = [:]
    lookups = [:]
    branchFailures = [:]
  }
}
