import Foundation

@testable import MultishellCore
@testable import MultishellProcess

/// The helper product, built beside the test bundle whatever the
/// configuration or scratch path; the test target depends on it.
enum HelperBinary {
  struct Missing: Error, CustomStringConvertible {
    let path: String
    var description: String {
      "no helper beside the test bundle at \(path); is MultishellCLI built?"
    }
  }

  static let url: URL = {
    let products = Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" }?
      .bundleURL.deletingLastPathComponent()
    return (products ?? URL(fileURLWithPath: ".build/debug")).appendingPathComponent(
      "multishell-helper"
    )
  }()

  /// Named here rather than found out from a launch error in every test.
  static func require() throws -> URL {
    guard FileManager.default.isExecutableFile(atPath: url.path) else {
      throw Missing(path: url.path)
    }
    return url
  }

  /// The helper, or `standIn` in its place, run as a hook would run it, with
  /// `stdin` piped in where given.
  static func run(
    _ arguments: [String],
    environment: [String: String] = [:],
    stdin: String? = nil,
    standIn: URL? = nil,
  ) async throws -> ProcessOutput {
    var environment = environment
    environment["PATH"] = ProcessInfo.processInfo.environment["PATH"]
    let runner = ProcessRunner()
    guard let stdin else {
      return try await runner.capture(
        standIn ?? require(),
        arguments,
        in: URL(fileURLWithPath: "/tmp"),
        environment: environment,
      )
    }
    // Stdin through a shell pipe, since the runner gives children /dev/null.
    let quoted = AnyShellQuoting.quote(stdin)
    let command =
      "printf '%s' \(quoted) | \(AnyShellQuoting.quote(try (standIn ?? require()).path)) "
      + AnyShellQuoting.commandLine(arguments)
    return try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"),
      ["-c", command],
      in: URL(fileURLWithPath: "/tmp"),
      environment: environment,
    )
  }
}
