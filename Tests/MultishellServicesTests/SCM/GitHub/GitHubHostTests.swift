import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct GitHubHostTests {
  private let pullRequest = Self.pullRequest(at: URL(fileURLWithPath: "/pull/44"))

  private static func pullRequest(at url: URL) -> PullRequest {
    PullRequest(
      number: 44,
      title: "Pull request 44",
      url: url,
      state: .open,
      review: .notRequired,
      blocker: nil,
      hasConflictAnswer: true,
      autoMergesWhenReady: false,
      isReadyToMerge: false,
      headBranch: "feat",
      headCommit: "tip",
      headRepository: RemoteRepository(owner: "me", name: "demo"),
      baseBranch: "main",
      updatedAt: Date(timeIntervalSince1970: 0),
    )
  }

  private func host(
    for tool: FakeTool,
    searchPath: String? = nil,
    loginVariables: [String: String] = [:],
  ) -> GitHubHost {
    GitHubHost(
      executable: tool.executable,
      searchPath: searchPath,
      runLog: tool.runLog,
      loginVariables: loginVariables,
    )
  }

  @Test func oneListCallReadsEveryPullRequestWithNoPromptOnTheLoginPath() async throws {
    let tool = try FakeTool(named: "gh", "cat <<'JSON'\n\(GitHubFixtures.open)\nJSON")
    defer { tool.tearDown() }
    let host = host(for: tool, searchPath: "/login/bin:/usr/bin:/bin")

    let pullRequests = try await host.pullRequests(in: tool.directory)

    #expect(pullRequests.map(\.number) == [40, 42, 41, 36, 29])
    let fields = GitHubPullRequestRecord.fields.joined(separator: ",")
    #expect(
      tool.calls == [
        FakeToolCall(
          arguments: "pr list --state all --limit \(GitHubHost.listLimit) --json \(fields)",
          variables: "PATH=/login/bin:/usr/bin:/bin GH_PROMPT_DISABLED=1 NO_COLOR=1 GH_TOKEN=",
        )
      ]
    )
  }

  @Test func aRemoteURLIsAskedWhichRepositoryItNamesToday() async throws {
    let tool = try FakeTool(named: "gh", #"echo '{"nameWithOwner":"vercel/next.js"}'"#)
    defer { tool.tearDown() }

    let repository = try await host(for: tool).repository(
      namedBy: "git@github.com:zeit/next.js.git",
      in: tool.directory,
    )

    #expect(repository == RemoteRepository(owner: "vercel", name: "next.js"))
    #expect(
      tool.calls.first?.arguments
        == "repo view git@github.com:zeit/next.js.git --json nameWithOwner"
    )
  }

  @Test func aBranchAskedAloneListsEveryPullRequestItHeadsOpenOrNot() async throws {
    let merged = GitHubFixtures.record(number: 7, state: "MERGED", headRefName: "old")
    let tool = try FakeTool(named: "gh", "echo '[\(merged)]'")
    defer { tool.tearDown() }
    let host = host(for: tool)

    let pullRequests = try await host.pullRequests(headedBy: "old", in: tool.directory)

    #expect(pullRequests.map(\.number) == [7])
    #expect(pullRequests.first?.state == .merged)
    let fields = GitHubPullRequestRecord.fields.joined(separator: ",")
    #expect(
      tool.calls.first?.arguments
        == "pr list --state all --head old --limit \(GitHubHost.branchListLimit) --json \(fields)"
    )
  }

  @Test func aBranchAskedAloneThatGhRefusesFailsWithWhatGhSaid() async throws {
    let tool = try FakeTool(named: "gh", "echo 'HTTP 502: Bad Gateway' >&2; exit 1")
    defer { tool.tearDown() }
    let host = host(for: tool)

    await #expect(throws: ServiceReadFailure.failed("HTTP 502: Bad Gateway")) {
      try await host.pullRequests(headedBy: "old", in: tool.directory)
    }
  }

  @Test func theLoginShellsVariablesReachTheTool() async throws {
    let tool = try FakeTool(named: "gh", "echo '[]'")
    defer { tool.tearDown() }
    let host = host(
      for: tool,
      searchPath: "/login/bin",
      loginVariables: ["GH_TOKEN": "from-zshrc"],
    )

    _ = try await host.pullRequests(in: tool.directory)

    #expect(tool.calls.first?.variables.hasSuffix("GH_TOKEN=from-zshrc") == true)
  }

  @Test func aLoginShellForcingColourCannotColourTheJSON() async throws {
    let tool = try FakeTool(
      named: "gh",
      #"[ "${CLICOLOR_FORCE:-0}" = 0 ] && echo '[]' || { echo forced >&2; exit 1; }"#,
    )
    defer { tool.tearDown() }
    let host = host(
      for: tool,
      searchPath: "/login/bin",
      loginVariables: ["CLICOLOR_FORCE": "1"],
    )

    #expect(try await host.pullRequests(in: tool.directory).isEmpty)
  }

  @Test func aRepositoryGhCannotPlaceOnGitHubFailsAsNotHosted() async throws {
    let tool = try FakeTool(
      named: "gh",
      """
      echo "none of the git remotes configured for this repository point to a known GitHub host." >&2
      exit 1
      """,
    )
    defer { tool.tearDown() }
    let host = host(for: tool)

    await #expect(throws: ServiceReadFailure.notHosted) {
      try await host.pullRequests(in: tool.directory)
    }
  }

  @Test func aNewPullRequestOfAForkNamesItsOwnerAndIsOpenedOnTheWeb() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = host(for: tool)

    try await host.openNewPullRequest(
      head: "k/tabs",
      in: RemoteRepository(owner: "me", name: "multishell"),
      base: "main",
      directory: tool.directory,
    )

    #expect(tool.calls.first?.arguments == "pr create --web --head me:k/tabs --base main")
  }

  @Test func mergeOptionsAreAskedOfTheRepositoryAndHostThePullRequestsPageNames() async throws {
    let tool = try FakeTool(named: "gh", "cat <<'JSON'\n\(GitHubFixtures.mergeOptions)\nJSON")
    defer { tool.tearDown() }
    let host = host(for: tool)
    let onEnterprise = Self.pullRequest(
      at: URL(string: "https://git.example.com/upstream/demo/pull/44")!
    )

    let options = try await host.mergeOptions(of: onEnterprise, in: tool.directory)

    #expect(options.methods == [.squash, .rebase])
    #expect(
      tool.calls.first?.arguments.hasPrefix(
        "api graphql --hostname git.example.com -f owner=upstream -f name=demo -F number=44 "
          + "-f query=query("
      ) == true
    )
  }

  @Test func aPullRequestWhosePageNamesNoRepositoryAsksNothing() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = host(for: tool)

    await #expect(
      throws: ServiceReadFailure.failed(
        t("integration.page-names-no-repository", "file:///pull/44")
      )
    ) {
      try await host.mergeOptions(of: pullRequest, in: tool.directory)
    }
    #expect(tool.calls.isEmpty)
  }

  @Test func aSquashIsHeldToTheHeadSeenAndCarriesTheEditedMessage() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = host(for: tool)

    try await host.merge(
      pullRequest,
      as: PullRequestMerge(
        method: .squash,
        message: PullRequestMergeMessage(subject: "-x looks like a flag", body: "Why"),
        headCommit: "tip",
        waitsForChecks: false,
      ),
      in: tool.directory,
    )

    #expect(
      tool.calls.first?.arguments
        == "pr merge file:///pull/44 --squash --match-head-commit=tip --subject=-x looks like a flag "
        + "--body=Why"
    )
  }

  @Test func aRebaseWaitingForChecksTurnsAutoMergeOnWithNoMessage() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = host(for: tool)

    try await host.merge(
      pullRequest,
      as: PullRequestMerge(method: .rebase, message: nil, headCommit: "tip", waitsForChecks: true),
      in: tool.directory,
    )
    try await host.disableAutoMerge(of: pullRequest, in: tool.directory)

    #expect(
      tool.calls.map(\.arguments) == [
        "pr merge file:///pull/44 --rebase --match-head-commit=tip --auto",
        "pr merge file:///pull/44 --disable-auto",
      ]
    )
  }

  @Test func aMergeGhRefusesThrowsWhatGhSaid() async throws {
    let tool = try FakeTool(
      named: "gh",
      "echo 'Head branch was modified. Review and try the merge again.' >&2; exit 1",
    )
    defer { tool.tearDown() }
    let host = host(for: tool)

    let error = await #expect(throws: ProcessFailure.self) {
      try await host.merge(
        pullRequest,
        as: PullRequestMerge(
          method: .merge,
          message: nil,
          headCommit: "old",
          waitsForChecks: false,
        ),
        in: tool.directory,
      )
    }
    #expect(error?.message.contains("Head branch was modified") == true)
  }

  @Test func theHeadIsReadByNumberAsTheChecksAre() async throws {
    let tool = try FakeTool(named: "gh", #"echo '{"headRefOid":"abc123"}'"#)
    defer { tool.tearDown() }

    let head = try await host(for: tool).headCommit(of: pullRequest, in: tool.directory)

    #expect(head == "abc123")
    #expect(tool.calls.map(\.arguments) == ["pr view 44 --json headRefOid"])
  }

  @Test func checksAreReadPendingOrFailingAndNoRequiredOnesReadsAsNone() async throws {
    let tool = try FakeTool(
      named: "gh",
      """
      case "$*" in
        *--required*) echo "no required checks reported on the 'feat' branch" >&2; exit 1 ;;
      esac
      echo '[{"name":"build","workflow":"CI","bucket":"pending"}]'
      exit 8
      """,
    )
    defer { tool.tearDown() }
    let host = host(for: tool)

    let checks = try await host.checks(of: pullRequest, in: tool.directory)

    #expect(
      checks == [
        PullRequestCheck(
          name: "build",
          workflow: "CI",
          status: .running,
          isRequired: false,
          link: nil,
        )
      ]
    )
    let fields = GitHubCheckRecord.fields.joined(separator: ",")
    #expect(
      Set(tool.calls.map(\.arguments)) == [
        "pr checks 44 --required --json \(fields)",
        "pr checks 44 --json \(fields)",
      ]
    )
  }

  @Test func aRunIsTimedInTheRunLogByItsProgramAndCommand() async throws {
    let tool = try FakeTool(named: "gh", "echo '[]'")
    defer { tool.tearDown() }
    tool.runLog.setRecording(true)
    let host = host(for: tool)

    _ = try await host.pullRequests(in: tool.directory)

    #expect(tool.runLog.drain().finishedRuns.map(\.command) == ["gh pr list"])
  }
  @Test func aFailedChecksLogIsReadFromItsJobsLogsEndpointWhichAnswersWhileItsRunGoes() async throws
  {
    let tool = try FakeTool(
      named: "gh",
      #"printf '2026-11-19T01:02:03.4567890Z error: boom\n'"#,
    )
    defer { tool.tearDown() }
    let check = PullRequestCheck(
      name: "test",
      workflow: "CI",
      status: .failed,
      isRequired: true,
      link: URL(string: "https://github.com/me/demo/actions/runs/7/job/135205394571"),
    )

    let log = try await host(for: tool).failedLog(of: check, keepingLast: 160, in: tool.directory)

    #expect(log?.text == "error: boom\n")
    #expect(
      tool.calls.first?.arguments
        == "api --hostname github.com --allow-escape-sequences repos/me/demo/actions/jobs/135205394571/logs"
    )
  }

  @Test func aCheckLinkingOutsideActionsHasNoLogAndAsksNothing() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let check = PullRequestCheck(
      name: "ci/circleci: build",
      workflow: nil,
      status: .failed,
      isRequired: true,
      link: URL(string: "https://circleci.com/gh/me/demo/12"),
    )

    let log = try await host(for: tool).failedLog(of: check, keepingLast: 160, in: tool.directory)

    #expect(log == nil)
    #expect(tool.calls.isEmpty)
  }

  @Test func unresolvedThreadsAreReadPageByPageUntilGitHubSaysThereAreNoMore() async throws {
    let tool = try FakeTool(
      named: "gh",
      """
      case "$*" in
        *after=c1*) cat <<'JSON'
      \(GitHubFixtures.reviewThreads(id: "t2", hasNextPage: false))
      JSON
        ;;
        *) cat <<'JSON'
      \(GitHubFixtures.reviewThreads(id: "t1", hasNextPage: true))
      JSON
        ;;
      esac
      """,
    )
    defer { tool.tearDown() }
    let onGitHub = Self.pullRequest(at: URL(string: "https://github.com/me/demo/pull/44")!)

    let threads = try await host(for: tool).unresolvedThreads(of: onGitHub, in: tool.directory)

    #expect(threads.map(\.id) == ["t1", "t2"])
    #expect(tool.calls.count == 2)
  }
}
