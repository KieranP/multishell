import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestStateTextTests {
  @Test func anOpenPullRequestSaysItsReviewThenWhatHoldsItBackThenAutoMerge() {
    let pullRequest = PullRequest.sample(
      review: .approved,
      blocker: .conflicts,
      autoMergesWhenReady: true,
    )
    #expect(pullRequest.stateText == "Approved · Conflicts with main · Merges when ready")
  }

  @Test func aBlockTheReviewExplainsIsNotSaidTwiceAndNoneNamesACause() {
    #expect(
      PullRequest.sample(review: .required, blocker: .blocked).stateText == "Review required"
    )
    #expect(
      PullRequest.sample(review: .approved, blocker: .blocked).stateText
        == "Approved · Blocked from merging into main"
    )
  }

  @Test func oneTheHostWouldMergeNowSaysSoInWordsAsWellAsGreen() {
    #expect(PullRequest.sample(isReadyToMerge: true).stateText == "Open · Ready to merge")
    #expect(
      PullRequest.sample(review: .approved, isReadyToMerge: true).stateText
        == "Approved · Ready to merge"
    )
  }

  @Test func changesRequestedAreNotCalledReadyWhateverTheHostSays() {
    #expect(
      PullRequest.sample(review: .changesRequested, isReadyToMerge: true).stateText
        == "Changes requested"
    )
  }

  @Test func aDraftSaysDraftWhateverItsReview() {
    #expect(PullRequest.sample(state: .draft, review: .approved).stateText == "Draft")
  }

  @Test func aMergedOrClosedOneSaysOnlyItsState() {
    #expect(
      PullRequest.sample(state: .merged, blocker: .conflicts).stateText == "Merged into main"
    )
    #expect(PullRequest.sample(state: .closed).stateText == "Closed without merging")
  }
}
