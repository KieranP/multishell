import Foundation

/// A CI provider that answers from a stand-in. Every repository runs on it, so a
/// scratch one needs no config file; opening a page does nothing.
struct StandInCIProvider: CIProvider {
  let standIn: ServiceStandIn

  /// The checkout itself, which is always there.
  var configurationPath: String { "." }

  func recentRuns(in directory: URL) async throws -> [CIRun] {
    standIn.runs
  }

  /// Up to `limit` of each repository's runs on the branch, as the tool's are
  /// one repository's: the reader keeps those of the project's own after.
  func runs(onBranch branch: String, limit: Int, in directory: URL) async throws -> [CIRun] {
    var taken: [String: Int] = [:]
    return try await recentRuns(in: directory).filter { run in
      guard run.branch == branch else { return false }
      let repository = run.repository?.identity ?? ""
      taken[repository, default: 0] += 1
      return taken[repository, default: 0] <= limit
    }
  }

  func workflows(of run: CIRun, in directory: URL) async throws -> [CIWorkflow] {
    standIn.workflows[run.id] ?? []
  }

  func failureReport(of run: CIRun, in directory: URL) async throws -> CIFailureReport {
    standIn.failureReports[run.id] ?? CIFailureReport(excerpts: [])
  }

  func openJob(id: String, in directory: URL) async throws {}

  func openRuns(onBranch branch: String, in directory: URL) async throws {}

  func canRead() async -> Bool { true }

  func toolStatus() async -> ServiceToolStatus {
    .ready(version: ServiceStandIn.toolVersion, account: nil)
  }
}
