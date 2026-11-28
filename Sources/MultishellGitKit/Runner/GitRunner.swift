import Foundation
import MultishellProcess

/// Runs git and hands back its standard output. Shelling out rather than
/// linking libgit2; see Docs/design/architecture.md.
struct GitRunner: Sendable {
  /// Signature lines read as reflog work, hidden untracked files as a clean tree,
  /// and columns put every merged branch on one line: each badged a branch wrongly.
  private static let forcedConfiguration = [
    "column.ui": "never",
    "log.showSignature": "false",
    "status.showUntrackedFiles": "normal",
  ]

  /// `git rev-parse --local-env-vars`: one exported in the user's rc would point
  /// every read at that repository, index or object store.
  private static let repositoryLocatingVariables: Set<String> = [
    "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_CONFIG", "GIT_CONFIG_COUNT",
    "GIT_CONFIG_PARAMETERS", "GIT_DIR", "GIT_GRAFT_FILE", "GIT_IMPLICIT_WORK_TREE",
    "GIT_INDEX_FILE", "GIT_NO_REPLACE_OBJECTS", "GIT_OBJECT_DIRECTORY", "GIT_PREFIX",
    "GIT_REPLACE_REF_BASE", "GIT_SHALLOW_FILE", "GIT_WORK_TREE",
  ]

  private let executable: URL
  private let processRunner = ProcessRunner()
  private let configuration: [String: String]
  /// The login shell's PATH where one was captured.
  private let searchPath: String?
  /// The login shell's, so a key agent, global config or SSH command set there
  /// reaches git as it does in a terminal.
  private let inheritedVariables: [String: String]
  /// Shared with the runner a later PATH builds, so Debug Info's counts
  /// carry across it.
  let runLog: GitRunLog

  /// The git on `searchPath`, or on the process's own PATH where there is none.
  init(
    searchPath: String? = nil,
    loginVariables: [String: String] = [:],
    configuration: [String: String] = [:],
    runLog: GitRunLog = GitRunLog(),
  ) throws {
    try self.init(
      executable: ExecutableLookup.find("git", searchPath: searchPath),
      searchPath: searchPath,
      loginVariables: loginVariables,
      configuration: configuration,
      runLog: runLog,
    )
  }

  /// `configuration` beats `forcedConfiguration` and git's own. Through the environment,
  /// not `-c`, which a failure would report in its arguments; see merged-branch.md.
  init(
    executable: URL?,
    searchPath: String? = nil,
    loginVariables: [String: String] = [:],
    configuration: [String: String] = [:],
    runLog: GitRunLog = GitRunLog(),
  ) throws {
    guard let executable else { throw GitUnavailable() }
    inheritedVariables = loginVariables.filter { Self.isInheritable($0.key) }
    self.executable = executable
    self.runLog = runLog
    self.configuration = Self.forcedConfiguration.merging(configuration) { _, callers in callers }
    self.searchPath = searchPath
  }

  /// Neither a repository-locating variable nor the locale, as alerts match git's English.
  private static func isInheritable(_ name: String) -> Bool {
    !repositoryLocatingVariables.contains(name) && name != "LANG" && name != "LANGUAGE"
      && !name.hasPrefix("LC_")
  }

  /// `GIT_CONFIG_*`, which git reads as config of the highest precedence, with
  /// `callConfiguration` beating the runner's own.
  private func environment(adding callConfiguration: [String: String]) -> [String: String] {
    let configuration = configuration.merging(callConfiguration) { _, callers in callers }
    var overrides = ["GIT_CONFIG_COUNT": String(configuration.count)]
    for (index, entry) in configuration.sorted(by: { $0.key < $1.key }).enumerated() {
      overrides["GIT_CONFIG_KEY_\(index)"] = entry.key
      overrides["GIT_CONFIG_VALUE_\(index)"] = entry.value
    }
    if let searchPath { overrides["PATH"] = searchPath }
    return inheritedVariables.merging(overrides) { _, ours in ours }
  }

  /// `environment` is a network call's no-prompt or a merge's no-editor; `timeout` is
  /// for fetch, push and `ls-remote`; `stopper` for the checkout a user may end, `add`.
  func run(
    _ arguments: [String],
    in directory: URL,
    configuration: [String: String] = [:],
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
  ) async throws -> String {
    try await succeededOutput(
      arguments,
      in: directory,
      configuration: configuration,
      environment: environment,
      timeout: timeout,
      stopper: stopper,
    ).standardOutput
  }

  /// `run`'s bytes undecoded, for output cut by size before it is read as text.
  func runBytes(_ arguments: [String], in directory: URL) async throws -> Data {
    try await succeededOutput(arguments, in: directory).standardOutputBytes
  }

  /// Throws `ProcessFailure` on a non-zero exit, as `run` and `runBytes` both do.
  private func succeededOutput(
    _ arguments: [String],
    in directory: URL,
    configuration: [String: String] = [:],
    environment: [String: String] = [:],
    timeout: Duration? = nil,
    stopper: ProcessStopper? = nil,
  ) async throws -> ProcessOutput {
    try await runLog.timing(GitCommandName.of(arguments), in: directory) { exitUsageProbe in
      try await processRunner.run(
        executable,
        arguments,
        in: directory,
        environment: self.environment(adding: configuration)
          .merging(environment) { _, callers in callers },
        timeout: timeout,
        stopper: stopper,
        exitUsageProbe: exitUsageProbe,
      )
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

  /// `output`'s bytes undecoded, for text that may be in another encoding.
  func outputBytes(_ arguments: [String], in directory: URL) async -> Data? {
    let output = await capture(arguments, in: directory)
    guard let output, output.succeeded else { return nil }
    return output.standardOutputBytes
  }

  /// The whole outcome, `nil` where the child could not be started.
  func capture(_ arguments: [String], in directory: URL) async -> ProcessOutput? {
    await runLog.timing(GitCommandName.of(arguments), in: directory) { exitUsageProbe in
      try? await processRunner.capture(
        executable,
        arguments,
        in: directory,
        environment: environment(adding: [:]),
        exitUsageProbe: exitUsageProbe,
      )
    }
  }
}
