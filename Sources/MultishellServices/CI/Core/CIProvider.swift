import Foundation

/// What runs a repository's CI, read through the provider's own tool.
/// CircleCI's is the one there is; see Docs/design/services.md.
public protocol CIProvider: Sendable {
  /// The file, relative to a checkout, that says a repository runs on this
  /// provider; a repository without it is never asked about.
  var configurationPath: String { get }

  /// The project's newest runs on any branch, newest first: one call for every
  /// branch the sidebar shows. Throws `ServiceReadFailure`.
  func recentRuns(in directory: URL) async throws -> [CIRun]

  /// One branch's newest runs, newest first: its history, and alone the
  /// newest of a branch the recent runs left out.
  func runs(onBranch branch: String, limit: Int, in directory: URL) async throws -> [CIRun]

  /// The run's workflows and their jobs, for the CI page.
  func workflows(of run: CIRun, in directory: URL) async throws -> [CIWorkflow]

  /// What failed in the run, condensed, as the provider words it, by job.
  func failureReport(of run: CIRun, in directory: URL) async throws -> CIFailureReport

  /// Opens one job in the browser.
  func openJob(id: String, in directory: URL) async throws

  /// Opens the branch's runs in the browser.
  func openRuns(onBranch branch: String, in directory: URL) async throws

  /// Whether this install has the commands the reads use, asked once it is
  /// found; an older one is left out rather than failing every poll.
  func canRead() async -> Bool

  func toolStatus() async -> ServiceToolStatus
}
