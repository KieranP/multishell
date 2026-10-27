import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellServices

@Suite
struct WorktreeServicesMatchingTests {
  private let upstream = BranchUpstream(remote: "origin", branch: "feat", tip: "tip")
  private let remotes = [
    GitRemote(name: "origin", url: "git@github.com:me/demo.git"),
    GitRemote(name: "upstream", url: "https://github.com/team/demo"),
  ]

  private func services(
    _ pullRequests: [PullRequest],
    upstream: BranchUpstream? = nil,
    localTip: String = "tip",
    runs: [String: CIRun] = [:],
    changesPastHead: [ChangesPastHead: Bool] = [:],
  ) -> WorktreeServices {
    WorktreeServices(
      upstream: upstream ?? self.upstream,
      localTip: localTip,
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: pullRequests,
        remotes: remotes,
      ),
      ciRuns: ProjectCIRuns(integration: .circleCI, remotes: remotes, runsByBranch: runs),
      changesPastHead: changesPastHead,
    )
  }

  @Test func aRunInAnotherRepositoryIsNotThisBranchs() {
    let theirs = CIRun.sample(
      id: "theirs",
      repository: RemoteRepository(owner: "team", name: "demo"),
    )
    let ours = CIRun.sample(id: "ours", repository: RemoteRepository(owner: "Me", name: "demo"))
    let unsaid = CIRun.sample(id: "unsaid")

    #expect(services([], runs: ["feat": theirs]).ciRun == nil)
    #expect(services([], runs: ["feat": ours]).ciRun?.id == "ours")
    #expect(services([], runs: ["feat": unsaid]).ciRun?.id == "unsaid")
  }

  @Test func thePullRequestIsTheOneHeadedByTheBranchsNameOnTheRemote() {
    let renamed = BranchUpstream(remote: "origin", branch: "shared/feat", tip: "tip")
    let found = services(
      [.sample(number: 1, headBranch: "feat"), .sample(number: 2, headBranch: "shared/feat")],
      upstream: renamed,
    )
    #expect(found.pullRequest?.number == 2)
  }

  @Test func aForksBranchOfTheSameNameIsNotThisBranchs() {
    let found = services([.sample(number: 7, owner: "someone-else")])
    #expect(found.pullRequest == nil)
  }

  @Test func theRemotesOwnerIsMatchedWithoutCase() {
    #expect(services([.sample(number: 7, owner: "Me")]).pullRequest?.number == 7)
  }

  @Test func anOpenPullRequestWinsOverANewerClosedOneAndTheNewestOpenWins() {
    let found = services([
      .sample(number: 1, state: .closed, updatedAt: Date(timeIntervalSince1970: 300)),
      .sample(number: 2, state: .draft, updatedAt: Date(timeIntervalSince1970: 100)),
      .sample(number: 3, state: .open, updatedAt: Date(timeIntervalSince1970: 200)),
    ])
    #expect(found.pullRequest?.number == 3)
  }

  @Test func aBranchIsMatchedInTheRepositoryItsRemotePushesTo() {
    let triangular = [
      GitRemote(
        name: "origin",
        url: "git@github.com:team/demo.git",
        pushURL: "git@github.com:me/demo.git",
      )
    ]
    let found = WorktreeServices(
      upstream: upstream,
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [.sample(number: 4, owner: "me")],
        remotes: triangular,
      ),
      ciRuns: nil,
    )
    #expect(found.pullRequest?.number == 4)
  }

  @Test func aMergedPullRequestStandsWhileItsHeadIsTheTip() {
    let merged = PullRequest.sample(number: 5, state: .merged, headCommit: "tip")
    #expect(services([merged]).pullRequest?.number == 5)
    #expect(services([merged]).outgrownPullRequest == nil)
  }

  @Test func aMergedPullRequestTheTipHasChangesPastIsOutgrownNotShown() {
    let merged = PullRequest.sample(number: 5, state: .merged, headCommit: "older")
    let pastOrRewritten = ChangesPastHead(
      head: "older",
      tip: "tip",
      ownRemote: "origin/feat",
      ownBranch: "feat",
    )
    let found = services([merged], localTip: "tip", changesPastHead: [pastOrRewritten: true])
    #expect(found.pullRequest == nil)
    #expect(found.outgrownPullRequest?.number == 5)
    #expect(found.showsAnything, "the row carries the tooltip that says so")
  }

  @Test func aMergedPullRequestTheTipHasNoChangesPastIsShownButNotOutgrown() {
    let merged = PullRequest.sample(number: 5, state: .merged, headCommit: "newer")
    let behind = ChangesPastHead(
      head: "newer",
      tip: "tip",
      ownRemote: "origin/feat",
      ownBranch: "feat",
    )
    let found = services([merged], localTip: "tip", changesPastHead: [behind: false])
    #expect(found.pullRequest?.number == 5)
    #expect(found.outgrownPullRequest == nil)
    #expect(found.changesPastMergedHead == behind)
  }

  @Test func aMergedPullRequestGitHasNotAnsweredForIsShownButNotOutgrown() {
    let merged = PullRequest.sample(number: 5, state: .merged, headCommit: "older")
    let found = services([merged], localTip: "tip")
    #expect(found.pullRequest?.number == 5)
    #expect(found.outgrownPullRequest == nil)
  }

  @Test func aBranchNobodyPushedHasNoPullRequestAndNoRun() {
    let found = WorktreeServices(
      upstream: nil,
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [.sample()],
        remotes: remotes,
      ),
      ciRuns: ProjectCIRuns(integration: .circleCI, runsByBranch: ["feat": .sample()]),
    )
    #expect(found.pullRequest == nil)
    #expect(found.ciRun == nil)
    #expect(!found.showsAnything)
  }

  @Test func theRunIsTheOneFiledUnderTheBranchsNameOnTheRemote() {
    let renamed = BranchUpstream(remote: "origin", branch: "shared/feat", tip: "tip")
    let found = services(
      [],
      upstream: renamed,
      runs: ["feat": .sample(id: "a"), "shared/feat": .sample(id: "b")],
    )
    #expect(found.ciRun?.id == "b")
  }

  @Test func aFailedReadIsSaidWithWhenTheShownAnswerWasRead() {
    let read = Date(timeIntervalSince1970: 1_800_000_000)
    let found = WorktreeServices(
      upstream: upstream,
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [.sample()],
        remotes: remotes,
        hasAnswered: true,
        failure: .loggedOut,
      ),
      ciRuns: nil,
      answeredAt: (read, nil),
    )
    #expect(found.pullRequest?.number == 44, "the last answer still shows")
    #expect(
      found.readProblem
        == ServiceReadProblem(integration: .gitHub, failure: .loggedOut, lastAnsweredAt: read)
    )
  }

  @Test func aRepositoryNotOnTheHostIsNoProblemToReport() {
    let found = WorktreeServices(
      upstream: upstream,
      localTip: "tip",
      localBranch: "feat",
      pullRequests: ProjectPullRequests(
        integration: .gitHub,
        pullRequests: [],
        remotes: remotes,
        failure: .notHosted,
      ),
      ciRuns: nil,
    )
    #expect(found.readProblem == nil)
  }
}
