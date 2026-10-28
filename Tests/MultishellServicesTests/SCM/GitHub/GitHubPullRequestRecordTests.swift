import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubPullRequestRecordTests {
  @Test func aMergedPullRequestReadsAsGhPrintsIt() throws {
    let pullRequests = try GitHubPullRequestRecord.pullRequests(
      from: Data(GitHubFixtures.merged.utf8)
    )

    let merged = try #require(pullRequests.first)
    #expect(merged.number == 3)
    #expect(merged.state == .merged)
    #expect(merged.review == .notRequired)
    #expect(merged.blocker == nil, "UNKNOWN is no blocker")
    #expect(!merged.autoMergesWhenReady)
    #expect(merged.headBranch == "more-highlighting")
    #expect(merged.headCommit == "b315c8c4fa48dea06f0c9f19388c0bd949879949")
    #expect(merged.headRepository == RemoteRepository(owner: "KieranP", name: "multishell"))
    #expect(merged.baseBranch == "main")
    #expect(merged.url == URL(string: "https://github.com/KieranP/multishell/pull/3"))
    #expect(merged.updatedAt == Date(timeIntervalSince1970: 1_792_650_349))
  }

  @Test func anOpenPullRequestSaysItsReviewItsBlockerAndAutoMerge() throws {
    let pullRequests = try GitHubPullRequestRecord.pullRequests(
      from: Data(GitHubFixtures.open.utf8)
    )
    let byNumber = Dictionary(uniqueKeysWithValues: pullRequests.map { ($0.number, $0) })

    #expect(byNumber[40]?.state == .open)
    #expect(byNumber[40]?.review == .approved)
    #expect(byNumber[40]?.blocker == .conflicts)
    #expect(byNumber[42]?.autoMergesWhenReady == true)
    #expect(byNumber[42]?.blocker == .behindBase)
    #expect(byNumber[42]?.review == .required)
    #expect(byNumber[41]?.state == .draft, "an open draft reads as a draft")
    #expect(byNumber[36]?.review == .changesRequested)
    #expect(byNumber[36]?.blocker == .blocked)
    #expect(byNumber[29]?.state == .closed)
  }

  /// GitHub works the merge state out lazily: a conflict may show in
  /// `mergeable` while `mergeStateStatus` still says it has not looked.
  @Test func aConflictIsTakenFromEitherField() throws {
    let json =
      "[\(GitHubFixtures.record(number: 7, mergeable: "CONFLICTING", mergeStateStatus: "UNKNOWN"))]"
    let pullRequest = try #require(
      try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).first
    )
    #expect(pullRequest.blocker == .conflicts)
    #expect(pullRequest.hasConflictAnswer)
  }

  @Test(arguments: [
    ("CLEAN", false, true),
    ("HAS_HOOKS", false, true),
    ("CLEAN", true, false),
    ("UNSTABLE", false, false),
    ("BLOCKED", false, false),
    ("UNKNOWN", false, false),
  ])
  func onlyAnOpenPullRequestGitHubCallsCleanIsReadyToMerge(
    mergeStateStatus: String,
    isDraft: Bool,
    isReady: Bool,
  ) throws {
    let json =
      "[\(GitHubFixtures.record(number: 7, isDraft: isDraft, mergeStateStatus: mergeStateStatus))]"
    let pullRequest = try #require(
      try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).first
    )
    #expect(pullRequest.isReadyToMerge == isReady)
  }

  @Test func aConflictTheOtherFieldReportsIsNotReadyThoughTheStateSaysClean() throws {
    let json =
      "[\(GitHubFixtures.record(number: 7, mergeable: "CONFLICTING", mergeStateStatus: "CLEAN"))]"
    let pullRequest = try #require(
      try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).first
    )
    #expect(!pullRequest.isReadyToMerge)
  }

  @Test func aMergedPullRequestIsNotReadyToMerge() throws {
    let json = "[\(GitHubFixtures.record(number: 7, state: "MERGED", mergeStateStatus: "CLEAN"))]"
    let pullRequest = try #require(
      try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).first
    )
    #expect(!pullRequest.isReadyToMerge)
  }

  @Test func aPullRequestGitHubHasNotCheckedForConflictsSaysSo() throws {
    let json =
      "[\(GitHubFixtures.record(number: 7, mergeable: "UNKNOWN", mergeStateStatus: "UNKNOWN"))]"
    let pullRequest = try #require(
      try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).first
    )
    #expect(pullRequest.blocker == nil)
    #expect(!pullRequest.hasConflictAnswer)
  }

  @Test func aRecordMissingAFieldOrNamingAnUnknownStateCostsItselfAlone() throws {
    let json = """
      [\(GitHubFixtures.record(number: 1)),
       \(GitHubFixtures.record(number: 2, state: "QUEUED")),
       {"number": "three"},
       \(GitHubFixtures.record(number: 4))]
      """
    let numbers = try GitHubPullRequestRecord.pullRequests(from: Data(json.utf8)).map(\.number)
    #expect(numbers == [1, 4])
  }

  @Test func outputThatIsNotAJsonArrayFailsTheReadRatherThanListingNone() {
    #expect(throws: ServiceReadFailure.self) {
      try GitHubPullRequestRecord.pullRequests(from: Data("Welcome to GitHub CLI!".utf8))
    }
  }
}
