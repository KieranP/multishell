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

  public init(
    executable: URL? = ExecutableLookup.find("git"), runner: ProcessRunner = ProcessRunner()
  ) throws {
    guard let executable else { throw GitUnavailable() }
    self.executable = executable
    self.runner = runner
  }

  /// `environment` and `timeout` are for the one call that talks to a
  /// network: see `WorktreeService.fetch`. Everything else reads the disk
  /// and finishes.
  public func run(
    _ arguments: [String], in directory: URL, environment: [String: String] = [:],
    timeout: Duration? = nil
  ) async throws -> String {
    try await runner.run(
      executable, arguments, in: directory, environment: environment, timeout: timeout)
  }

  public func succeeds(_ arguments: [String], in directory: URL) async -> Bool {
    let output = try? await runner.capture(executable, arguments, in: directory)
    return output?.succeeded ?? false
  }

  /// The output where git succeeded, `nil` where it failed. For the reads a
  /// poll makes, where a repository that cannot answer is not an error to
  /// raise but a badge not to draw.
  public func output(_ arguments: [String], in directory: URL) async -> String? {
    let output = try? await runner.capture(executable, arguments, in: directory)
    guard let output, output.succeeded else { return nil }
    return output.standardOutput
  }
}
