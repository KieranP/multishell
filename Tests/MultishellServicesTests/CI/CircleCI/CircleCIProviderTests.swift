import Foundation
import Testing

@testable import MultishellServices

@Suite
struct CircleCIProviderTests {
  private func provider(for tool: FakeTool) -> CircleCIProvider {
    CircleCIProvider(executable: tool.executable, searchPath: nil, runLog: tool.runLog)
  }

  @Test func recentRunsAreOneCallForTheWholeProject() async throws {
    let tool = try FakeTool(named: "circleci", "cat <<'JSON'\n\(CircleCIFixtures.runList)\nJSON")
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    let runs = try await provider.recentRuns(in: tool.directory)

    #expect(runs.count == 3)
    #expect(
      tool.calls.first?.arguments == "run list --json --limit \(CircleCIProvider.recentRunLimit)"
    )
  }

  @Test func aStartedRunHeadsItsBranchAheadOfTheFailureBeforeIt() async throws {
    let tool = try FakeTool(
      named: "circleci",
      "cat <<'JSON'\n\(CircleCIFixtures.startedThenFailedRunList)\nJSON",
    )
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    let runs = try await provider.recentRuns(in: tool.directory)

    #expect(runs.map(\.id) == ["started", "failed"])
    #expect(runs.map(\.status) == [.running, .failed])
    #expect(runs.map(\.isUnderWay) == [true, false])
  }

  @Test func aBranchAskedAloneWhoseOnlyRunHasStartedAnswersWithThatRun() async throws {
    let tool = try FakeTool(
      named: "circleci",
      "cat <<'JSON'\n\(CircleCIFixtures.startedRun)\nJSON",
    )
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    let runs = try await provider.runs(onBranch: "feat", limit: 1, in: tool.directory)

    #expect(runs.map(\.id) == ["started"])
    #expect(runs.first?.status == .running)
  }

  @Test func aBranchAskedAloneWhoseRunIsInUnknownWordsAnswersWithThatRunAsUnknown() async throws {
    let tool = try FakeTool(
      named: "circleci",
      "echo '[\(CircleCIFixtures.run(id: "x", branch: "feat", phase: "paused", currentOutcome: nil))]'",
    )
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    let runs = try await provider.runs(onBranch: "feat", limit: 1, in: tool.directory)

    #expect(runs.map(\.status) == [.unknown])
  }

  @Test func aBranchLeftOutOfTheRecentRunsIsAskedForByName() async throws {
    let tool = try FakeTool(
      named: "circleci",
      "echo '[\(CircleCIFixtures.run(id: "x", branch: "old"))]'",
    )
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    let runs = try await provider.runs(onBranch: "old", limit: 1, in: tool.directory)

    #expect(runs.map(\.id) == ["x"])
    #expect(tool.calls.first?.arguments == "run list --json --limit 1 --branch old")
  }

  @Test func aLoggedOutCLIFailsAsLoggedOut() async throws {
    let tool = try FakeTool(
      named: "circleci",
      "echo 'Error: not authenticated, run circleci auth login' >&2; exit 1",
    )
    defer { tool.tearDown() }
    let provider = provider(for: tool)

    await #expect(throws: ServiceReadFailure.loggedOut) {
      try await provider.recentRuns(in: tool.directory)
    }
  }

  @Test func aBranchsHistoryAFailureReportAndAJobAreAskedByName() async throws {
    let tool = try FakeTool(named: "circleci", "echo '[]'")
    defer { tool.tearDown() }
    let provider = provider(for: tool)
    let run = CIRun(
      id: "r1",
      branch: "feat",
      commit: "abc",
      subject: nil,
      status: .failed,
      isFinished: true,
      createdAt: nil,
    )

    _ = try await provider.runs(onBranch: "feat", limit: 10, in: tool.directory)
    let report = try await provider.failureReport(of: run, in: tool.directory)
    try await provider.openJob(id: "j2", in: tool.directory)

    #expect(report.excerpts == [CIFailureExcerpt(workflow: nil, job: nil, text: "[]")])
    #expect(
      tool.calls.map(\.arguments) == [
        "run list --json --limit 10 --branch feat",
        "run get r1 --failure-report --no-interactive",
        "job open j2",
      ]
    )
  }
}
