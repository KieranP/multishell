import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// CI runs on CircleCI, read through `circleci` 1.0 or later, which keeps the
/// login and finds the project from the repository's remote.
public struct CircleCIProvider: CIProvider {
  /// Enough to cover the branches a sidebar shows in one call; one left out
  /// is asked for alone.
  static let recentRunLimit = 50

  /// No colour, and no update check, which asks GitHub for a release.
  private static let quietEnvironment = [
    "NO_COLOR": "1",
    "CIRCLECI_CLI_SKIP_UPDATE_CHECK": "true",
  ]

  public let configurationPath = ".circleci/config.yml"
  private let runner: ServiceToolRunner

  public init(
    executable: URL,
    searchPath: String?,
    runLog: GitRunLog,
    loginVariables: [String: String] = [:],
  ) {
    runner = ServiceToolRunner(
      executable: executable,
      searchPath: searchPath,
      quietEnvironment: Self.quietEnvironment,
      runLog: runLog,
      loginVariables: loginVariables,
    )
  }

  public func recentRuns(in directory: URL) async throws -> [CIRun] {
    let arguments = ["run", "list", "--json", "--limit", String(Self.recentRunLimit)]
    return try CircleCIRunRecord.runs(from: try await read(arguments, in: directory))
  }

  public func runs(onBranch branch: String, limit: Int, in directory: URL) async throws -> [CIRun] {
    let arguments = ["run", "list", "--json", "--limit", String(limit), "--branch", branch]
    return try CircleCIRunRecord.runs(from: try await read(arguments, in: directory))
  }

  public func failureReport(of run: CIRun, in directory: URL) async throws -> CIFailureReport {
    let arguments = ["run", "get", run.id, "--failure-report", "--no-interactive"]
    let text = String(decoding: try await read(arguments, in: directory), as: UTF8.self)
    return CircleCIFailureReportText.report(from: text)
  }

  public func workflows(of run: CIRun, in directory: URL) async throws -> [CIWorkflow] {
    try CircleCIRunRecord.workflows(
      from: try await read(["run", "get", run.id, "--json", "--no-interactive"], in: directory)
    )
  }

  public func openJob(id: String, in directory: URL) async throws {
    _ = try await runner.run(["job", "open", id], in: directory)
  }

  public func openRuns(onBranch branch: String, in directory: URL) async throws {
    _ = try await runner.run(["run", "open", "--branch", branch], in: directory)
  }

  /// `circleci version` alone, which asks no service; one that fails to run,
  /// a cold start under a scan say, leaves the tool in.
  public func canRead() async -> Bool {
    guard let version = try? await runner.run(["version"], in: ServiceToolRunner.noRepository)
    else { return true }
    return CircleCIToolReport.canRead(versionOutput: version)
  }

  /// `circleci auth me` asks the service, so this is for the Integrations
  /// page alone.
  public func toolStatus() async -> ServiceToolStatus {
    await runner.toolStatus(
      versionArguments: ["version"],
      authArguments: ["auth", "me"],
      report: CircleCIToolReport.status(versionOutput:authMe:),
    )
  }

  private func read(_ arguments: [String], in directory: URL) async throws -> Data {
    try await runner.read(arguments, in: directory, failure: CircleCIErrorText.failure(from:))
  }
}
