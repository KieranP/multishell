import Testing

@testable import MultishellAppCore

@Suite
struct PullRequestPageWordingTests {
  @Test func aBranchWithoutAPullRequestSaysWhetherTheRemoteHasIt() {
    let pushed = PullRequestPage.noPullRequest(branch: "feat", isPushed: true)
    let unpushed = PullRequestPage.noPullRequest(branch: "feat", isPushed: false)

    #expect(pushed.emptyText?.title == "No pull request for feat")
    #expect(pushed.emptyText?.detail == "feat is pushed and has no pull request yet.")
    #expect(unpushed.emptyText?.detail?.hasPrefix("The remote has no feat yet.") == true)
  }

  @Test func anUnreadListSaysWhyWhereAReadFailedAndAShownPullRequestSaysNothing() {
    #expect(PullRequestPage.notRead(problem: "offline").emptyText?.detail == "offline")
    #expect(PullRequestPage.pullRequest(.sample()).emptyText == nil)
  }
}
