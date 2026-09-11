import Foundation
import MultishellProcess

public struct GitUnavailable: Error, CustomStringConvertible {
  public init() {}
  public var description: String { "git was not found on PATH" }
}

/// Runs git and hands back its standard output. Shelling out rather than
/// linking libgit2; see docs/design/architecture.md.
public struct GitRunner: Sendable {
  private let executable: URL
  private let runner: ProcessRunner
  /// `GIT_CONFIG_*`, which git reads as config of the highest precedence.
  private let configEnvironment: [String: String]

  /// `configuration` overrides git's own for the life of the runner. Through
  /// the environment, not `-c`, which a failure would report in its arguments.
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
  /// network; see `WorktreeService.fetch`.
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

  /// The output where git succeeded, `nil` where it failed. For a poll's
  /// reads, where a repository that cannot answer is a badge not drawn.
  public func output(_ arguments: [String], in directory: URL) async -> String? {
    let output = try? await runner.capture(
      executable, arguments, in: directory, environment: configEnvironment)
    guard let output, output.succeeded else { return nil }
    return output.standardOutput
  }
}
