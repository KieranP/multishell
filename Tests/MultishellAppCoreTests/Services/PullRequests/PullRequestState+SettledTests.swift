import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestStateSettledTests {
  @Test func onlyAMergedOrClosedPullRequestIsSettled() {
    #expect(PullRequestState.merged.isSettled)
    #expect(PullRequestState.closed.isSettled)
    #expect(!PullRequestState.open.isSettled)
    #expect(!PullRequestState.draft.isSettled)
  }
}
