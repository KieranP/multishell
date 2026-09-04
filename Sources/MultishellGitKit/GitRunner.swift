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

  public func run(_ arguments: [String], in directory: URL) async throws -> String {
    try await runner.run(executable, arguments, in: directory)
  }

  public func succeeds(_ arguments: [String], in directory: URL) async -> Bool {
    let output = try? await runner.capture(executable, arguments, in: directory)
    return output?.succeeded ?? false
  }
}
