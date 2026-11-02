import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct BranchPullRequestLookupTests {
  @Test func aMergedOrClosedAnswerStandsUntilTheBranchIsPushedTo() {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .merged), .sample(number: 2, state: .closed)],
    )
    #expect(lookup.stillAnswers(upstreamTip: "a"))
    #expect(!lookup.stillAnswers(upstreamTip: "b"))
  }

  @Test func aBranchHeadingNoneIsNotAskedAgainUntilPushedTo() {
    #expect(
      BranchPullRequestLookup(upstreamTip: "a", pullRequests: []).stillAnswers(upstreamTip: "a")
    )
  }

  @Test func aBranchTheRemoteDeletedIsAskedAgainOnceItIsPushedBack() {
    let gone = BranchPullRequestLookup(upstreamTip: nil, pullRequests: [.sample(state: .merged)])
    #expect(gone.stillAnswers(upstreamTip: nil))
    #expect(!gone.stillAnswers(upstreamTip: "a"))
  }

  @Test(arguments: [PullRequestState.open, .draft])
  func anOpenOrDraftAnswerIsAskedAgainEveryRead(state: PullRequestState) {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .merged), .sample(number: 2, state: state)],
    )
    #expect(!lookup.stillAnswers(upstreamTip: "a"))
  }
}
