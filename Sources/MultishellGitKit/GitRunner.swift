import Foundation
import MultishellProcess

/// Runs git and hands back its standard output. Shelling out rather than
/// linking libgit2; see Docs/design/architecture.md.
public struct GitRunner: Sendable {
  private let executable: URL
  private let runner: ProcessRunner
  /// `GIT_CONFIG_*`, which git reads as config of the highest precedence,
  /// and the login shell's PATH where one was captured.
  private let configEnvironment: [String: String]

  /// Set on every runner: signature lines read as reflog work, and untracked
  /// files hidden read as a clean tree. Both badge wrongly and offer a delete.
  private static let isolation = [
    "log.showSignature": "false",
    "status.showUntrackedFiles": "normal",
  ]

  /// The git on `searchPath`, or on the process's own PATH where there is none.
  public init(
    runner: ProcessRunner = ProcessRunner(), searchPath: String? = nil,
    configuration: [String: String] = [:]
  ) throws {
    try self.init(
      executable: ExecutableLookup.find("git", path: searchPath), runner: runner,
      searchPath: searchPath, configuration: configuration)
  }

  /// `configuration` beats `isolation` and git's own. Through the environment,
  /// not `-c`, which a failure would report in its arguments; see merged-branch.md.
  public init(
    executable: URL?, runner: ProcessRunner = ProcessRunner(),
    searchPath: String? = nil, configuration: [String: String] = [:]
  ) throws {
    guard let executable else { throw GitUnavailable() }
    self.executable = executable
    self.runner = runner
    // Never empty now, `isolation` being in every runner, so no guard on it.
    let configuration = Self.isolation.merging(configuration) { _, callers in callers }
    var overrides = ["GIT_CONFIG_COUNT": String(configuration.count)]
    for (index, entry) in configuration.sorted(by: { $0.key < $1.key }).enumerated() {
      overrides["GIT_CONFIG_KEY_\(index)"] = entry.key
      overrides["GIT_CONFIG_VALUE_\(index)"] = entry.value
    }
    if let searchPath { overrides["PATH"] = searchPath }
    self.configEnvironment = overrides
  }

  /// `environment` and `timeout` are for the one call that talks to a network,
  /// `WorktreeGit.fetch`; `stopper` for the checkout a user may end, `add`.
  public func run(
    _ arguments: [String], in directory: URL, environment: [String: String] = [:],
    timeout: Duration? = nil, stopper: ProcessStopper? = nil
  ) async throws -> String {
    try await runner.run(
      executable, arguments, in: directory,
      environment: configEnvironment.merging(environment) { _, callers in callers },
      timeout: timeout, stopper: stopper)
  }

  func succeeds(_ arguments: [String], in directory: URL) async -> Bool {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    return output?.succeeded ?? false
  }

  /// The exit status of a run nobody stopped, `nil` where there was none.
  func exitStatus(_ arguments: [String], in directory: URL) async -> Int32? {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    guard let output, output.stop == nil else { return nil }
    return output.status
  }

  /// The output where git succeeded, `nil` where it failed. For a poll's
  /// reads, where a repository that cannot answer is a badge not drawn.
  func output(_ arguments: [String], in directory: URL) async -> String? {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    guard let output, output.succeeded else { return nil }
    return output.standardOutput
  }
}
