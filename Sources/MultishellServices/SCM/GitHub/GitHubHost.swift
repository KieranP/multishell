import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// Pull requests on GitHub, read through `gh`, which keeps the login and
/// knows an Enterprise host from the repository's remotes.
public struct GitHubHost: PullRequestHost {
  /// Enough for every open pull request of a busy repository and the recently
  /// closed ones; an older one past it reads as no pull request.
  static let listLimit = 100

  /// No prompt, no colour and no update check, which writes a state file.
  private static let quietEnvironment = [
    "GH_NO_UPDATE_NOTIFIER": "1",
    "GH_NO_EXTENSION_UPDATE_NOTIFIER": "1",
    "GH_PROMPT_DISABLED": "1",
    "GH_SPINNER_DISABLED": "1",
    "NO_COLOR": "1",
  ]

  private let runner: ServiceToolRunner

  public init(
    executable: URL,
    searchPath: String?,
    runLog: GitRunLog,
    loginVariables: [String: String] = [:],
  ) {
    runner = ServiceToolRunner(
      executable: executable,
      searchPath: searchPath,
      quietEnvironment: Self.quietEnvironment,
      runLog: runLog,
      loginVariables: loginVariables,
    )
  }

  public func pullRequests(in directory: URL) async throws -> [PullRequest] {
    let json = try await runner.read(
      [
        "pr", "list", "--state", "all", "--limit", String(Self.listLimit),
        "--json", GitHubPullRequestRecord.fields.joined(separator: ","),
      ],
      in: directory,
      failure: GitHubErrorText.failure(from:),
    )
    return try GitHubPullRequestRecord.pullRequests(from: json)
  }

  /// Every check on its head, and which the base branch requires: two calls,
  /// `--required` being the only way `gh` says so.
  public func checks(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws
    -> [PullRequestCheck]
  {
    let number = String(pullRequest.number)
    let fields = ["--json", GitHubCheckRecord.fields.joined(separator: ",")]
    async let required = checksJSON(
      ["pr", "checks", number, "--required"] + fields,
      in: directory,
    )
    async let all = checksJSON(["pr", "checks", number] + fields, in: directory)
    return try await GitHubCheckRecord.checks(
      from: all,
      required: GitHubCheckRecord.keys(from: required),
    )
  }

  public func open(_ pullRequest: PullRequest, in directory: URL) async throws {
    _ = try await runner.run(["pr", "view", String(pullRequest.number), "--web"], in: directory)
  }

  /// `--head` names the branch already pushed, so `gh` asks nothing about
  /// pushing; a fork's head carries its owner.
  public func openNewPullRequest(
    head: String,
    in headRepository: RemoteRepository?,
    base: String,
    directory: URL,
  ) async throws {
    let qualifiedHead = headRepository.map { "\($0.owner):\(head)" } ?? head
    _ = try await runner.run(
      ["pr", "create", "--web", "--head", qualifiedHead, "--base", base],
      in: directory,
    )
  }

  /// `gh pr checks` exits 1 for a failing check and 8 for a pending one, its
  /// list printed either way, and 1 with no list where there are no checks.
  private func checksJSON(_ arguments: [String], in directory: URL) async throws -> Data {
    try await runner.read(arguments, in: directory, failure: GitHubErrorText.failure(from:)) {
      output in
      if output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
        return output.standardOutputBytes
      }
      let saysNone = ["no checks reported", "no required checks reported"].contains { said in
        output.standardError.contains(said)
      }
      return saysNone ? Data("[]".utf8) : nil
    }
  }

  /// `gh auth status` asks every host it is logged in to, so this is for the
  /// Integrations page alone.
  public func toolStatus() async -> ServiceToolStatus {
    await runner.toolStatus(
      versionArguments: ["--version"],
      authArguments: ["auth", "status"],
      report: GitHubToolReport.status(versionOutput:authStatus:),
    )
  }
}
