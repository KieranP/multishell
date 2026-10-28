import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct WorktreeServicesWordingTests {
  private func services(
    _ pullRequest: PullRequest? = nil,
    run: CIRun? = nil,
    localTip: String = "tip",
    failure: ServiceReadFailure? = nil,
    changesPastHead: [ChangesPastHead: Bool] = [:],
  ) -> WorktreeServices {
    WorktreeServices(
      upstream: BranchUpstream(remote: "origin", branch: "feat", tip: localTip),
      localTip: localTip,
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: pullRequest.map { [$0] } ?? [],
        remotes: [GitRemote(name: "origin", url: "git@github.com:me/demo.git")],
        hasAnswered: true,
        failure: failure,
      ),
      ciRuns: ProjectCIRuns(integration: .circleCI, runsByBranch: run.map { ["feat": $0] } ?? [:]),
      answeredAt: (Date(timeIntervalSince1970: 1_700_000_000), nil),
      changesPastHead: changesPastHead,
    )
  }

  @Test func theTooltipIsTheNumberAndTitleThenStateThenRun() {
    let tooltip = services(.sample(number: 44, review: .required), run: .sample(status: .passed))
      .tooltip
    #expect(tooltip == "#44 Pull request 44\nReview required\nCircleCI passed")
  }

  @Test func aRunOfAnotherCommitNamesIt() {
    let text = services(run: .sample(commit: "9f8e7d6c5b", status: .running)).ciRunText
    #expect(text == "CircleCI running on 9f8e7d6, not the local tip")
  }

  @Test func aRunNamingTheLocalTipByItsShortFormIsTheLocalTip() {
    let tip = "9f2bcef611313c5e74b18f3fa2ea96498e378cde"
    #expect(
      services(run: .sample(commit: "9f2bcef"), localTip: tip).ciRunText == "CircleCI passed"
    )
  }

  @Test func aFailedReadSaysWhyAndSinceWhen() throws {
    let text = try #require(services(.sample(), failure: .loggedOut).readProblemText)
    #expect(text.hasPrefix("Not updated since "))
    #expect(text.hasSuffix("GitHub is not logged in"))
  }

  @Test func aScreenReaderHearsWhatTheTooltipSaysMakesTheRowOld() throws {
    let stale = services(.sample(), failure: .loggedOut)
    let problem = try #require(stale.readProblemText)
    #expect(stale.spokenSummary?.hasSuffix(problem) == true)
  }

  @Test func aRowDrawingNoServicesSaysNothingOfAFailedRead() {
    #expect(services(failure: .loggedOut).spokenSummary == nil)
  }

  @Test func anAnswerFromAnotherDaySaysItsDate() throws {
    let text = try #require(services(.sample(), failure: .loggedOut).readProblemText)
    #expect(text.contains("2023"), "the shown answer dates from November 2023")
  }

  @Test func aMergedPullRequestTheBranchWentPastIsSaidAsSuch() {
    let outgrown = services(
      .sample(number: 33, state: .merged, headCommit: "older"),
      changesPastHead: [
        ChangesPastHead(
          head: "older",
          tip: "tip",
          ownRemoteBranch: "origin/feat",
          ownBranch: "feat",
        ):
          true
      ],
    )
    #expect(outgrown.outgrownText == "#33 was merged before this branch's last commits")
    #expect(outgrown.spokenSummary == outgrown.outgrownText, "the row draws it, so says it")
  }
}
