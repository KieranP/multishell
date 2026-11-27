import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct BranchPullRequestLookupTests {
  private static let mine = [RemoteRepository(owner: "me", name: "demo")]

  @Test func aMergedOrClosedAnswerStandsUntilTheBranchIsPushedTo() {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .merged), .sample(number: 2, state: .closed)],
    )
    #expect(lookup.stillAnswers(upstreamTip: "a", headedIn: Self.mine))
    #expect(!lookup.stillAnswers(upstreamTip: "b", headedIn: Self.mine))
  }

  @Test func aBranchHeadingNoneIsNotAskedAgainUntilPushedTo() {
    #expect(
      BranchPullRequestLookup(upstreamTip: "a", pullRequests: []).stillAnswers(
        upstreamTip: "a",
        headedIn: Self.mine,
      )
    )
  }

  @Test func aBranchTheRemoteDeletedIsAskedAgainOnceItIsPushedBack() {
    let gone = BranchPullRequestLookup(upstreamTip: nil, pullRequests: [.sample(state: .merged)])
    #expect(gone.stillAnswers(upstreamTip: nil, headedIn: Self.mine))
    #expect(!gone.stillAnswers(upstreamTip: "a", headedIn: Self.mine))
  }

  @Test(arguments: [PullRequestState.open, .draft])
  func anOpenOrDraftAnswerIsAskedAgainEveryRead(state: PullRequestState) {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .merged), .sample(number: 2, state: state)],
    )
    #expect(!lookup.stillAnswers(upstreamTip: "a", headedIn: Self.mine))
  }

  @Test func aForksOpenAnswerStandsUntilTheBranchIsPushedTo() {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .open, owner: "someone-else")],
    )
    #expect(lookup.stillAnswers(upstreamTip: "a", headedIn: Self.mine))
  }

  @Test func anOpenAnswerIsAskedAgainWhereTheRemoteNamesNoRepository() {
    let lookup = BranchPullRequestLookup(
      upstreamTip: "a",
      pullRequests: [.sample(number: 1, state: .open, owner: "someone-else")],
    )
    #expect(!lookup.stillAnswers(upstreamTip: "a", headedIn: []))
  }
}
