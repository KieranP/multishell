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

  /// No prompt, no colour and no update check, which writes a state file. A
  /// login shell's `CLICOLOR_FORCE` outranks `NO_COLOR` and colours `--json`.
  private static let quietEnvironment = [
    "CLICOLOR_FORCE": "0",
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

  private static func flag(of method: PullRequestMergeMethod) -> String {
    switch method {
    case .merge: "--merge"
    case .rebase: "--rebase"
    case .squash: "--squash"
    }
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

  /// No `gh pr` command prints GitHub's own merge messages, so this asks its
  /// GraphQL API through `gh api`, which still keeps the login and the host.
  public func mergeOptions(
    of pullRequest: PullRequest,
    in directory: URL,
  ) async throws -> PullRequestMergeOptions {
    guard let address = GitHubPullRequestAddress(pullRequest.url) else {
      throw ServiceReadFailure.failed(
        t("integration.page-names-no-repository", pullRequest.url.absoluteString)
      )
    }
    // `-f`, not `-F`, so an owner named all in digits stays a string.
    let json = try await runner.read(
      [
        "api", "graphql", "--hostname", address.host,
        "-f", "owner=\(address.repository.owner)", "-f", "name=\(address.repository.name)",
        "-F", "number=\(pullRequest.number)", "-f", "query=\(GitHubMergeOptionsRecord.query)",
      ],
      in: directory,
      failure: GitHubErrorText.failure(from:),
    )
    return try GitHubMergeOptionsRecord.options(from: json)
  }

  /// Named by its page, the repository the options were read of, not by its
  /// number in whichever `gh repo set-default` names. Each value joins its flag.
  public func merge(
    _ pullRequest: PullRequest,
    as merge: PullRequestMerge,
    in directory: URL,
  ) async throws {
    var arguments = [
      "pr", "merge", pullRequest.url.absoluteString, Self.flag(of: merge.method),
      "--match-head-commit=\(merge.headCommit)",
    ]
    if let message = merge.message {
      arguments += ["--subject=\(message.subject)", "--body=\(message.body)"]
    }
    if merge.waitsForChecks { arguments.append("--auto") }
    try await runner.run(arguments, in: directory, timeout: ServiceToolRunner.writeTimeout)
  }

  public func disableAutoMerge(of pullRequest: PullRequest, in directory: URL) async throws {
    try await runner.run(
      ["pr", "merge", pullRequest.url.absoluteString, "--disable-auto"],
      in: directory,
      timeout: ServiceToolRunner.writeTimeout,
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
