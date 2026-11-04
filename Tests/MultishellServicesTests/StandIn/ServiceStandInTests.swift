import Foundation
import Testing

@testable import MultishellServices

struct ServiceStandInTests {
  private static let json = """
    {
      "pullRequests": [{
        "number": 42, "title": "Add the switcher", "state": "open", "review": "approved",
        "headBranch": "feat/switcher", "headCommit": "0123456789abcdef",
        "headRepository": "git@github.com:acme/app.git",
        "checks": [{"name": "build", "status": "passed", "isRequired": true}]
      }],
      "ciRuns": [
        {"id": "r1", "branch": "main", "commit": "aaaaaaa", "status": "passed",
         "createdAt": "2026-10-28T10:00:00Z"},
        {"id": "r2", "branch": "feat/switcher", "commit": "0123456", "status": "failed",
         "createdAt": "2026-10-29T10:00:00Z",
         "workflows": [{"name": "ci", "status": "failed",
                        "jobs": [{"id": "j1", "name": "test", "status": "failed"}]}],
         "failures": [{"workflow": "ci", "job": "test", "text": "1 test failed"}]},
        {"id": "r3", "branch": "feat/switcher", "commit": "0123456", "status": "running"}
      ]
    }
    """

  private static let here = URL(filePath: "/repo")

  @Test func theHostListsTheStandInsPullRequestWithItsChecks() async throws {
    let host = try ServiceStandIn(json: Self.json).pullRequestHost

    let pullRequests = try await host.pullRequests(in: Self.here)
    let checks = try await host.checks(of: try #require(pullRequests.first), in: Self.here)

    #expect(pullRequests.map(\.number) == [42])
    #expect(pullRequests.first?.review == .approved)
    #expect(
      pullRequests.first?.headRepository.isSame(as: RemoteRepository(owner: "acme", name: "app"))
        == true
    )
    #expect(checks.map(\.name) == ["build"])
    #expect(checks.first?.isRequired == true)
  }

  @Test func anOwnerAndNameStandForTheHeadRepositorysURL() async throws {
    let json = """
      {"pullRequests": [{"number": 1, "title": "t", "state": "draft", "headBranch": "b",
        "headCommit": "c", "headRepository": "acme/app"}]}
      """

    let pullRequests = try await ServiceStandIn(json: json).pullRequestHost.pullRequests(
      in: Self.here
    )

    #expect(
      pullRequests.first?.headRepository.isSame(as: RemoteRepository(owner: "acme", name: "app"))
        == true
    )
  }

  @Test func theProviderListsRunsNewestFirstAndOneBranchsAlone() async throws {
    let provider = try ServiceStandIn(json: Self.json).ciProvider

    let recent = try await provider.recentRuns(in: Self.here)
    let branch = try await provider.runs(onBranch: "feat/switcher", limit: 1, in: Self.here)

    #expect(recent.map(\.id) == ["r2", "r1", "r3"])
    #expect(branch.map(\.id) == ["r2"])
  }

  @Test func aRunWithNoFinishSaidIsFinishedUnlessStillRunning() async throws {
    let runs = try await ServiceStandIn(json: Self.json).ciProvider.recentRuns(in: Self.here)

    #expect(runs.map(\.isFinished) == [true, true, false])
  }

  @Test func aRunsWorkflowsAndFailureReportAreTheStandIns() async throws {
    let provider = try ServiceStandIn(json: Self.json).ciProvider
    let run = try #require(try await provider.recentRuns(in: Self.here).first)

    let workflows = try await provider.workflows(of: run, in: Self.here)
    let report = try await provider.failureReport(of: run, in: Self.here)

    #expect(workflows.map(\.name) == ["ci"])
    #expect(workflows.first?.jobs.map(\.name) == ["test"])
    #expect(report.excerpt(ofJob: "test", inWorkflow: "ci") == "1 test failed")
  }

  @Test func anUnknownStatusIsRefusedNamingWhereItStands() {
    let json = """
      {"ciRuns": [{"id": "r", "branch": "b", "commit": "c", "status": "green"}]}
      """

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(
      error?.reason.hasPrefix("at ciRuns.0.status: ") == true,
      "\(String(describing: error))",
    )
  }

  @Test func pullRequestsOfTwoRepositoriesWithOneNumberKeepTheirOwnChecks() async throws {
    let json = """
      {"pullRequests": [
        {"number": 1, "title": "a", "state": "open", "headBranch": "a", "headCommit": "1",
         "headRepository": "me/a", "checks": [{"name": "lint", "status": "failed"}]},
        {"number": 1, "title": "b", "state": "open", "headBranch": "b", "headCommit": "2",
         "headRepository": "me/b", "checks": [{"name": "build", "status": "passed"}]}
      ]}
      """
    let host = try ServiceStandIn(json: json).pullRequestHost

    let pullRequests = try await host.pullRequests(in: Self.here)
    let second = try #require(pullRequests.first { $0.headBranch == "b" })

    #expect(try await host.checks(of: second, in: Self.here).map(\.name) == ["build"])
  }

  @Test func aRunIDGivenTwiceIsRefusedNamingTheSecond() {
    let json = """
      {"ciRuns": [{"id": "r", "branch": "a", "commit": "1", "status": "passed"},
                  {"id": "r", "branch": "b", "commit": "2", "status": "failed"}]}
      """

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(error?.reason.hasPrefix("at ciRuns.1.id: ") == true, "\(String(describing: error))")
  }

  @Test func aHeadRepositoryWithNoOwnerIsRefusedNamingWhere() {
    let json = """
      {"pullRequests": [{"number": 1, "title": "a", "state": "open", "headBranch": "a",
        "headCommit": "1", "headRepository": "demo"}]}
      """

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(
      error?.reason.hasPrefix("at pullRequests.0.headRepository: ") == true,
      "\(String(describing: error))",
    )
  }

  @Test func aPullRequestGivenTwiceIsRefusedNamingTheSecond() {
    let json = """
      {"pullRequests": [
        {"number": 7, "title": "a", "state": "open", "headBranch": "a", "headCommit": "1",
         "headRepository": "me/demo"},
        {"number": 7, "title": "b", "state": "open", "headBranch": "a", "headCommit": "2",
         "headRepository": "me/demo"}
      ]}
      """

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(
      error?.reason.hasPrefix("at pullRequests.1.number: ") == true,
      "\(String(describing: error))",
    )
  }

  @Test func aRunNamesTheRepositoryItRanIn() async throws {
    let json = """
      {"ciRuns": [{"id": "r", "branch": "main", "commit": "1", "status": "passed",
                   "repository": "me/other"}]}
      """

    let run = try #require(
      try await ServiceStandIn(json: json).ciProvider.recentRuns(in: Self.here).first
    )

    #expect(run.repository?.isSame(as: RemoteRepository(owner: "me", name: "other")) == true)
  }

  @Test func aLocalPathOrFileURLIsNoHeadRepository() {
    for repository in ["/Users/me/demo", "file:///x/y/z", "./repos/demo", "../demo"] {
      let json = """
        {"pullRequests": [{"number": 1, "title": "a", "state": "open", "headBranch": "a",
          "headCommit": "1", "headRepository": "\(repository)"}]}
        """

      #expect(throws: ServiceStandInUnreadable.self, "\(repository)") {
        try ServiceStandIn(json: json)
      }
    }
  }

  @Test func aDateWithFractionalSecondsIsRead() async throws {
    let json = """
      {"ciRuns": [{"id": "r", "branch": "b", "commit": "1", "status": "passed",
                   "createdAt": "2026-10-29T10:00:00.123Z"}]}
      """

    let run = try #require(
      try await ServiceStandIn(json: json).ciProvider.recentRuns(in: Self.here).first
    )

    #expect(run.createdAt != nil)
  }

  @Test func aKeyNoRecordHasIsRefusedNamingWhere() {
    let json = """
      {"pullRequests": [{"number": 1, "title": "a", "state": "open", "headBranch": "a",
        "headCommit": "1", "headRepository": "me/demo", "url": "https://x/1",
        "reviews": "approved"}]}
      """

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(
      error?.reason.hasPrefix("at pullRequests.0.reviews: ") == true,
      "\(String(describing: error))",
    )
  }

  @Test func aMissingKeyIsNamedInThePath() {
    let json = #"{"ciRuns": [{"id": "r", "branch": "b", "status": "passed"}]}"#

    let error = #expect(throws: ServiceStandInUnreadable.self) { try ServiceStandIn(json: json) }

    #expect(
      error?.reason.hasPrefix("at ciRuns.0.commit: ") == true,
      "\(String(describing: error))",
    )
  }

  @Test func aBranchsHistoryHoldsEveryRunOfItWhateverItsRepository() async throws {
    let json = """
      {"ciRuns": [
        {"id": "a", "branch": "main", "commit": "1", "status": "passed", "repository": "me/other"},
        {"id": "b", "branch": "main", "commit": "2", "status": "passed", "repository": "me/demo"}
      ]}
      """

    let runs = try await ServiceStandIn(json: json).ciProvider.runs(
      onBranch: "main",
      limit: 1,
      in: Self.here,
    )

    #expect(Set(runs.map(\.id)) == ["a", "b"])
  }

  @Test func undatedPullRequestsKeepTheOrderTheyAreGivenIn() async throws {
    let json = """
      {"pullRequests": [
        {"number": 1, "title": "a", "state": "open", "headBranch": "f", "headCommit": "1",
         "headRepository": "me/demo", "url": "https://x/1"},
        {"number": 2, "title": "b", "state": "closed", "headBranch": "f", "headCommit": "2",
         "headRepository": "me/demo", "url": "https://x/2"}
      ]}
      """

    let pullRequests = try await ServiceStandIn(json: json).pullRequestHost.pullRequests(
      in: Self.here
    )

    #expect(pullRequests.map(\.number) == [1, 2])
  }

  @Test func aPullRequestWithNoURLIsGivenItsGitHubPage() async throws {
    let json = """
      {"pullRequests": [{"number": 7, "title": "a", "state": "open", "headBranch": "a",
        "headCommit": "1", "headRepository": "me/demo"}]}
      """

    let pullRequests = try await ServiceStandIn(json: json).pullRequestHost.pullRequests(
      in: Self.here
    )

    #expect(pullRequests.first?.url.absoluteString == "https://github.com/me/demo/pull/7")
  }

  @Test func aStandInGivingEveryFieldIsRead() throws {
    let json = """
      {"pullRequests": [{"number": 1, "title": "a", "url": "https://x/1", "state": "open",
        "review": "approved", "blocker": "conflicts", "autoMergesWhenReady": true,
        "isReadyToMerge": false, "headBranch": "a", "headCommit": "1",
        "headRepository": "me/demo", "baseBranch": "main", "updatedAt": "2026-10-29T10:00:00Z",
        "checks": [{"name": "build", "workflow": "ci", "status": "passed", "isRequired": true,
                    "link": "https://x/c"}]}],
       "ciRuns": [{"id": "r", "branch": "a", "commit": "1", "subject": "s", "status": "failed",
        "isFinished": true, "createdAt": "2026-10-29T10:00:00Z", "repository": "me/demo",
        "workflows": [{"name": "ci", "status": "failed",
                       "jobs": [{"id": "j", "name": "test", "status": "failed"}]}],
        "failures": [{"workflow": "ci", "job": "test", "text": "boom"}]}]}
      """
    let standIn = try ServiceStandIn(json: json)

    let pullRequest = try #require(standIn.pullRequests.first)
    let check = try #require(standIn.checks[ServiceStandIn.key(of: pullRequest)]?.first)
    let run = try #require(standIn.runs.first)
    let job = try #require(standIn.workflows["r"]?.first?.jobs.first)

    #expect(pullRequest.url.absoluteString == "https://x/1")
    #expect(pullRequest.review == .approved && pullRequest.blocker == .conflicts)
    #expect(pullRequest.autoMergesWhenReady && !pullRequest.isReadyToMerge)
    #expect(pullRequest.baseBranch == "main" && pullRequest.updatedAt != .distantPast)
    #expect(
      check.workflow == "ci" && check.isRequired && check.link?.absoluteString == "https://x/c"
    )
    #expect(run.subject == "s" && run.isFinished && run.createdAt != nil)
    #expect(run.repository?.isSame(as: RemoteRepository(owner: "me", name: "demo")) == true)
    #expect(job.id == "j" && job.status == .failed)
    #expect(standIn.failureReports["r"]?.excerpt(ofJob: "test", inWorkflow: "ci") == "boom")
  }

  @Test func aBranchsHistoryHoldsUpToTheLimitOfEachRepositorysRuns() async throws {
    let json = """
      {"ciRuns": [
        {"id": "a1", "branch": "main", "commit": "1", "status": "passed", "repository": "me/a",
         "createdAt": "2026-10-29T10:00:00Z"},
        {"id": "a2", "branch": "main", "commit": "2", "status": "passed", "repository": "me/a",
         "createdAt": "2026-10-28T10:00:00Z"},
        {"id": "b1", "branch": "main", "commit": "3", "status": "passed", "repository": "me/b"}
      ]}
      """

    let runs = try await ServiceStandIn(json: json).ciProvider.runs(
      onBranch: "main",
      limit: 1,
      in: Self.here,
    )

    #expect(Set(runs.map(\.id)) == ["a1", "b1"])
  }

  @Test func oneForksPullRequestsIntoTwoBasesMayShareANumber() throws {
    let json = """
      {"pullRequests": [
        {"number": 5, "title": "a", "state": "open", "headBranch": "a", "headCommit": "1",
         "headRepository": "me/demo", "baseBranch": "main"},
        {"number": 5, "title": "b", "state": "open", "headBranch": "b", "headCommit": "2",
         "headRepository": "me/demo", "baseBranch": "release"}
      ]}
      """

    _ = try ServiceStandIn(json: json)
  }

  @Test func aPullRequestsChecksAreFoundThoughItWasListedAtAnotherMoment() async throws {
    let json = """
      {"pullRequests": [{"number": 7, "title": "a", "state": "open", "headBranch": "a",
        "headCommit": "1", "headRepository": "me/demo",
        "checks": [{"name": "build", "status": "passed"}]}]}
      """
    let first = try ServiceStandIn(json: json).pullRequestHost
    let second = try ServiceStandIn(json: json).pullRequestHost
    let listed = try #require(try await first.pullRequests(in: Self.here).first)

    let checks = try await second.checks(of: listed, in: Self.here)

    #expect(checks.map(\.name) == ["build"])
  }

  @Test func undatedRunsKeepTheOrderTheyAreGivenIn() async throws {
    let json = """
      {"ciRuns": [
        {"id": "x", "branch": "b", "commit": "1", "status": "passed"},
        {"id": "y", "branch": "b", "commit": "2", "status": "passed"},
        {"id": "z", "branch": "b", "commit": "3", "status": "passed"}
      ]}
      """

    let runs = try await ServiceStandIn(json: json).ciProvider.recentRuns(in: Self.here)

    #expect(runs.map(\.id) == ["x", "y", "z"])
  }

  @Test func basesDifferingInCaseAreTwoBases() throws {
    let json = """
      {"pullRequests": [
        {"number": 5, "title": "a", "state": "open", "headBranch": "a", "headCommit": "1",
         "headRepository": "me/demo", "baseBranch": "Main"},
        {"number": 5, "title": "b", "state": "open", "headBranch": "b", "headCommit": "2",
         "headRepository": "me/demo", "baseBranch": "main"}
      ]}
      """

    _ = try ServiceStandIn(json: json)
  }

  @Test func anUndatedPullRequestIsTakenForTheOldest() async throws {
    let json = """
      {"pullRequests": [
        {"number": 1, "title": "a", "state": "open", "headBranch": "f", "headCommit": "1",
         "headRepository": "me/demo"},
        {"number": 2, "title": "b", "state": "merged", "headBranch": "f", "headCommit": "2",
         "headRepository": "me/demo", "updatedAt": "2020-01-01T00:00:00Z"}
      ]}
      """

    let pullRequests = try await ServiceStandIn(json: json).pullRequestHost.pullRequests(
      in: Self.here
    )

    #expect(pullRequests.map(\.number) == [2, 1])
  }
}
