import Foundation
import Subprocess
import System

@testable import MultishellProcess

/// A child in a session of its own, as the app starts one. `Process` hands on
/// the test run's terminal, where an interactive shell stops on SIGTTIN.
public enum Detached {
  public enum StandardError: Sendable {
    case withOutput
    case discarded
  }

  /// Everything the child wrote before it and every inheritor of its output
  /// closed it. `environment` is the whole environment, nothing inherited.
  public static func output(
    of executable: String, _ arguments: [String], environment: [String: String],
    in directory: URL? = nil, input: String = "", standardError: StandardError = .withOutput
  ) async throws -> String {
    let configuration = Configuration(
      executable: .path(FilePath(executable)), arguments: Arguments(arguments),
      environment: .custom(
        Dictionary(
          uniqueKeysWithValues: environment.map { (Environment.Key(stringLiteral: $0), $1) })),
      workingDirectory: directory.map { FilePath($0.path) },
      platformOptions: DetachedLaunch.platformOptions)
    let limit = 16 << 20
    switch standardError {
    case .withOutput:
      return try await run(
        configuration, input: .string(input), output: .string(limit: limit),
        error: .combinedWithOutput
      ).standardOutput
    case .discarded:
      return try await run(
        configuration, input: .string(input), output: .string(limit: limit), error: .discarded
      ).standardOutput
    }
  }
}
