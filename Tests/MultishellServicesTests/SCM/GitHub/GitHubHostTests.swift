import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct GitHubHostTests {
  private let pullRequest = PullRequest(
    number: 44,
    title: "Pull request 44",
    url: URL(fileURLWithPath: "/pull/44"),
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

  @Test func oneListCallReadsEveryPullRequestWithNoPromptOnTheLoginPath() async throws {
    let tool = try FakeTool(named: "gh", "cat <<'JSON'\n\(GitHubFixtures.open)\nJSON")
    defer { tool.tearDown() }
    let host = GitHubHost(
      executable: tool.executable,
      searchPath: "/login/bin:/usr/bin:/bin",
      runLog: tool.runLog,
    )

    let pullRequests = try await host.pullRequests(in: tool.directory)

    #expect(pullRequests.map(\.number) == [40, 42, 41, 36, 29])
    let fields = GitHubPullRequestRecord.fields.joined(separator: ",")
    #expect(
      tool.calls == [
        "pr list --state all --limit \(GitHubHost.listLimit) --json \(fields)",
        "PATH=/login/bin:/usr/bin:/bin GH_PROMPT_DISABLED=1 NO_COLOR=1 GH_TOKEN=",
      ]
    )
  }

  @Test func theLoginShellsVariablesReachTheTool() async throws {
    let tool = try FakeTool(named: "gh", "echo '[]'")
    defer { tool.tearDown() }
    let host = GitHubHost(
      executable: tool.executable,
      searchPath: "/login/bin",
      runLog: tool.runLog,
      loginVariables: ["GH_TOKEN": "from-zshrc"],
    )

    _ = try await host.pullRequests(in: tool.directory)

    #expect(tool.calls.contains { $0.hasSuffix("GH_TOKEN=from-zshrc") })
  }

  @Test func aLoginShellForcingColourCannotColourTheJSON() async throws {
    let tool = try FakeTool(
      named: "gh",
      #"[ "${CLICOLOR_FORCE:-0}" = 0 ] && echo '[]' || { echo forced >&2; exit 1; }"#,
    )
    defer { tool.tearDown() }
    let host = GitHubHost(
      executable: tool.executable,
      searchPath: "/login/bin",
      runLog: tool.runLog,
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
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

    await #expect(throws: ServiceReadFailure.notHosted) {
      try await host.pullRequests(in: tool.directory)
    }
  }

  @Test func aNewPullRequestOfAForkNamesItsOwnerAndIsOpenedOnTheWeb() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

    try await host.openNewPullRequest(
      head: "k/tabs",
      in: RemoteRepository(owner: "me", name: "multishell"),
      base: "main",
      directory: tool.directory,
    )

    #expect(tool.calls.first == "pr create --web --head me:k/tabs --base main")
  }

  @Test func mergeOptionsAreAskedOfTheRepositoryAndHostThePullRequestsPageNames() async throws {
    let tool = try FakeTool(named: "gh", "cat <<'JSON'\n\(GitHubFixtures.mergeOptions)\nJSON")
    defer { tool.tearDown() }
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)
    let onEnterprise = PullRequest(
      number: 44,
      title: "Pull request 44",
      url: URL(string: "https://git.example.com/upstream/demo/pull/44")!,
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

    let options = try await host.mergeOptions(of: onEnterprise, in: tool.directory)

    #expect(options.methods == [.squash, .rebase])
    #expect(
      tool.calls.first?.hasPrefix(
        "api graphql --hostname git.example.com -f owner=upstream -f name=demo -F number=44 "
          + "-f query=query("
      ) == true
    )
  }

  @Test func aPullRequestWhosePageNamesNoRepositoryAsksNothing() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

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
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

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
      tool.calls.first
        == "pr merge file:///pull/44 --squash --match-head-commit=tip --subject=-x looks like a flag "
        + "--body=Why"
    )
  }

  @Test func aRebaseWaitingForChecksTurnsAutoMergeOnWithNoMessage() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

    try await host.merge(
      pullRequest,
      as: PullRequestMerge(method: .rebase, message: nil, headCommit: "tip", waitsForChecks: true),
      in: tool.directory,
    )
    try await host.disableAutoMerge(of: pullRequest, in: tool.directory)

    let commands = tool.calls.filter { !$0.hasPrefix("PATH=") }
    #expect(
      commands == [
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
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

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
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

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
      Set(tool.calls.filter { $0.hasPrefix("pr") }) == [
        "pr checks 44 --required --json \(fields)",
        "pr checks 44 --json \(fields)",
      ]
    )
  }

  @Test func aRunIsCountedInTheGitLogByItsProgramAndCommand() async throws {
    let tool = try FakeTool(named: "gh", "echo '[]'")
    defer { tool.tearDown() }
    tool.runLog.setRecording(true)
    let host = GitHubHost(executable: tool.executable, searchPath: nil, runLog: tool.runLog)

    _ = try await host.pullRequests(in: tool.directory)

    #expect(tool.runLog.drain().finishedRuns.map(\.command) == ["gh pr list"])
  }
}
