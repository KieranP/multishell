import Foundation
import MultishellProcess

/// Runs git and hands back its standard output. Shelling out rather than
/// linking libgit2; see Docs/design/architecture.md.
struct GitRunner: Sendable {
  private let executable: URL
  private let processRunner = ProcessRunner()
  /// `GIT_CONFIG_*`, which git reads as config of the highest precedence,
  /// and the login shell's PATH where one was captured.
  private let baseEnvironment: [String: String]
  /// Shared with the runner a later PATH builds, so Debug Info's counts
  /// carry across it.
  let runLog: GitRunLog

  /// Set on every runner: signature lines read as reflog work, and untracked
  /// files hidden read as a clean tree. Both badge wrongly and offer a delete.
  private static let forcedConfiguration = [
    "log.showSignature": "false",
    "status.showUntrackedFiles": "normal",
  ]

  /// The git on `searchPath`, or on the process's own PATH where there is none.
  init(
    searchPath: String? = nil, configuration: [String: String] = [:],
    runLog: GitRunLog = GitRunLog()
  ) throws {
    try self.init(
      executable: ExecutableLookup.find("git", searchPath: searchPath), searchPath: searchPath,
      configuration: configuration, runLog: runLog)
  }

  /// `configuration` beats `forcedConfiguration` and git's own. Through the environment,
  /// not `-c`, which a failure would report in its arguments; see merged-branch.md.
  init(
    executable: URL?, searchPath: String? = nil, configuration: [String: String] = [:],
    runLog: GitRunLog = GitRunLog()
  ) throws {
    guard let executable else { throw GitUnavailable() }
    self.executable = executable
    self.runLog = runLog
    let configuration = Self.forcedConfiguration.merging(configuration) { _, callers in callers }
    var overrides = ["GIT_CONFIG_COUNT": String(configuration.count)]
    for (index, entry) in configuration.sorted(by: { $0.key < $1.key }).enumerated() {
      overrides["GIT_CONFIG_KEY_\(index)"] = entry.key
      overrides["GIT_CONFIG_VALUE_\(index)"] = entry.value
    }
    if let searchPath { overrides["PATH"] = searchPath }
    self.baseEnvironment = overrides
  }

  /// `environment` and `timeout` are for the one call that talks to a network,
  /// `WorktreeGit.fetch`; `stopper` for the checkout a user may end, `add`.
  func run(
    _ arguments: [String], in directory: URL, environment: [String: String] = [:],
    timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws -> String {
    try await logged(arguments, in: directory) { exitUsageProbe in
      try await processRunner.run(
        executable, arguments, in: directory,
        environment: baseEnvironment.merging(environment) { _, callers in callers },
        timeout: timeout, stopper: stopper, exitUsageProbe: exitUsageProbe)
    }
  }

  func succeeds(_ arguments: [String], in directory: URL) async -> Bool {
    let output = await capture(arguments, in: directory)
    return output?.succeeded ?? false
  }

  /// The exit status, `nil` where git could not be started.
  func exitStatus(_ arguments: [String], in directory: URL) async -> Int32? {
    await capture(arguments, in: directory)?.status
  }

  /// The output where git succeeded, `nil` where it failed. For a poll's
  /// reads, where a repository that cannot answer is a badge not drawn.
  func output(_ arguments: [String], in directory: URL) async -> String? {
    let output = await capture(arguments, in: directory)
    guard let output, output.succeeded else { return nil }
    return output.standardOutput
  }

  /// The whole outcome, `nil` where the child could not be started.
  private func capture(_ arguments: [String], in directory: URL) async -> ProcessOutput? {
    await logged(arguments, in: directory) { exitUsageProbe in
      try? await processRunner.capture(
        executable, arguments, in: directory, environment: baseEnvironment,
        exitUsageProbe: exitUsageProbe)
    }
  }
}
