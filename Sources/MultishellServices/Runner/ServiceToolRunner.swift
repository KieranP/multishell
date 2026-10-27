import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// Runs a service's command-line tool, `gh` or `circleci`, timed into the
/// git run log so Debug Info counts it beside git's own.
struct ServiceToolRunner: Sendable {
  /// Each is a network call; one hung on a dead connection must end.
  private static let timeout: Duration = .seconds(30)
  /// Where a call that needs no repository runs, a version or a login.
  static let noRepository = URL(fileURLWithPath: "/", isDirectory: true)

  private let executable: URL
  private let processRunner = ProcessRunner()
  /// The login shell's variables, a token kept there among them, and its PATH,
  /// then the tool's own switches for no prompt, colour or update check.
  private let environment: [String: String]
  private let runLog: GitRunLog

  init(
    executable: URL,
    searchPath: String?,
    quietEnvironment: [String: String],
    runLog: GitRunLog,
    loginVariables: [String: String],
  ) {
    self.executable = executable
    var environment = loginVariables.merging(quietEnvironment) { _, quiet in quiet }
    if let searchPath { environment["PATH"] = searchPath }
    self.environment = environment
    self.runLog = runLog
  }

  /// What the tool printed where it exited 0. Any other exit throws
  /// `ProcessFailure`, whose message is its stderr.
  func run(_ arguments: [String], in directory: URL) async throws -> String {
    try await capture(arguments, in: directory)
      .requiringSuccess(of: executable, arguments: arguments).standardOutput
  }

  /// What a read printed, or `answerDespiteExit`'s answer to a failing exit;
  /// every failure throws `ServiceReadFailure`, the tool's words by `failure`.
  func read(
    _ arguments: [String],
    in directory: URL,
    failure: (String) -> ServiceReadFailure,
    answerDespiteExit: (ProcessOutput) -> Data? = { _ in nil },
  ) async throws(ServiceReadFailure) -> Data {
    let output: ProcessOutput
    do {
      output = try await capture(arguments, in: directory)
    } catch {
      // A launch that failed says so in words, not as a raw system error.
      throw .failed(t("integration.not-run", executable.lastPathComponent))
    }
    if output.succeeded { return output.standardOutputBytes }
    if output.stopReason != nil { throw .failed(t("integration.timed-out")) }
    if let answer = answerDespiteExit(output) { return answer }
    throw failure(said(by: output))
  }

  /// Its stderr, else its stdout, else its exit: an empty reason reads as
  /// "Not read yet: " with nothing after it.
  private func said(by output: ProcessOutput) -> String {
    let words = [output.standardError, output.standardOutput]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
    return words ?? t("integration.exited", executable.lastPathComponent, String(output.status))
  }

  /// What the tool says of its version and its login, asked where no
  /// repository is, for the Integrations page.
  func toolStatus(
    versionArguments: [String],
    authArguments: [String],
    report: (String, ProcessOutput) -> ServiceToolStatus,
  ) async -> ServiceToolStatus {
    guard let version = try? await run(versionArguments, in: Self.noRepository) else {
      return .unreadable(t("integration.no-version"))
    }
    guard let auth = try? await capture(authArguments, in: Self.noRepository) else {
      return .unreadable(t("integration.no-auth-status"))
    }
    return report(version, auth)
  }

  /// The whole outcome, for the reads whose failure says something.
  private func capture(_ arguments: [String], in directory: URL) async throws -> ProcessOutput {
    try await runLog.timing(commandName(of: arguments), in: directory) { exitUsageProbe in
      try await processRunner.capture(
        executable,
        arguments,
        in: directory,
        environment: environment,
        timeout: Self.timeout,
        exitUsageProbe: exitUsageProbe,
      )
    }
  }

  /// `gh pr list`: the program and its words before the first flag, so two
  /// reads of different branches count as one command.
  private func commandName(of arguments: [String]) -> String {
    ([executable.lastPathComponent] + arguments.prefix { !$0.hasPrefix("-") }.prefix(2))
      .joined(separator: " ")
  }
}
