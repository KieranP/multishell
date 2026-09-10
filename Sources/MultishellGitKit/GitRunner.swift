import Foundation
import MultishellProcess

public struct GitUnavailable: Error, CustomStringConvertible {
  public init() {}
  public var description: String { "git was not found on PATH" }
}

/// Runs git and hands back its standard output.
///
/// Shelling out rather than linking libgit2: git's worktree support is the
/// part libgit2 covers worst, and the porcelain formats are a stable contract.
public struct GitRunner: Sendable {
  private let executable: URL
  private let runner: ProcessRunner
  /// `GIT_CONFIG_*`, which git reads as config of the highest precedence.
  private let configEnvironment: [String: String]

  /// `configuration` overrides git's own config for the life of the runner,
  /// whatever repository a command runs against. The app passes none; the
  /// test fixtures pass `commit.gpgsign=false`, so a developer whose global
  /// config signs is not asked for the key once per fixture commit, and a
  /// repository a later test clones is covered without being told. It goes
  /// through the environment rather than `-c`, which would show up in the
  /// arguments a failure is reported with.
  public init(
    executable: URL? = ExecutableLookup.find("git"), runner: ProcessRunner = ProcessRunner(),
    configuration: [String: String] = [:]
  ) throws {
    guard let executable else { throw GitUnavailable() }
    self.executable = executable
    self.runner = runner
    var overrides: [String: String] = [:]
    if !configuration.isEmpty {
      overrides["GIT_CONFIG_COUNT"] = String(configuration.count)
      for (index, entry) in configuration.sorted(by: { $0.key < $1.key }).enumerated() {
        overrides["GIT_CONFIG_KEY_\(index)"] = entry.key
        overrides["GIT_CONFIG_VALUE_\(index)"] = entry.value
      }
    }
    self.configEnvironment = overrides
  }

  /// `environment` and `timeout` are for the one call that talks to a
  /// network: see `WorktreeService.fetch`. Everything else reads the disk
  /// and finishes.
  public func run(
    _ arguments: [String], in directory: URL, environment: [String: String] = [:],
    timeout: Duration? = nil
  ) async throws -> String {
    try await runner.run(
      executable, arguments, in: directory,
      environment: configEnvironment.merging(environment) { _, callers in callers },
      timeout: timeout)
  }

  public func succeeds(_ arguments: [String], in directory: URL) async -> Bool {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    return output?.succeeded ?? false
  }

  /// The output where git succeeded, `nil` where it failed. For the reads a
  /// poll makes, where a repository that cannot answer is not an error to
  /// raise but a badge not to draw.
  public func output(_ arguments: [String], in directory: URL) async -> String? {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    guard let output, output.succeeded else { return nil }
    return output.standardOutput
  }
}
