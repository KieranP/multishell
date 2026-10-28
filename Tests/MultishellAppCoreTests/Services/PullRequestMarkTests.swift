import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct PullRequestMarkTests {
  @Test(arguments: [
    (PullRequestReview.approved, PullRequestMark.Tone.primary),
    (.changesRequested, .changesRequested),
    (.required, .secondary),
    (.notRequired, .primary),
  ])
  func anOpenPullRequestNotYetReadyTakesItsReviewsColour(
    review: PullRequestReview,
    tone: PullRequestMark.Tone,
  ) {
    let mark = PullRequestMark(.sample(state: .open, review: review))
    #expect(mark.shape == .open)
    #expect(mark.tone == tone)
  }

  @Test(arguments: [PullRequestReview.approved, .notRequired])
  func anOpenPullRequestReadyToMergeIsReadyToMergesColour(review: PullRequestReview) {
    let mark = PullRequestMark(.sample(state: .open, review: review, isReadyToMerge: true))
    #expect(mark.tone == .readyToMerge)
  }

  @Test func changesRequestedStayRedWhereTheHostWouldMergeAnyway() {
    let mark = PullRequestMark(.sample(review: .changesRequested, isReadyToMerge: true))
    #expect(mark.tone == .changesRequested)
  }

  @Test func aDraftIsDashedAndFaintWhateverItsReview() {
    #expect(
      PullRequestMark(.sample(state: .draft, review: .approved))
        == PullRequestMark(.sample(state: .draft))
    )
    #expect(PullRequestMark(.sample(state: .draft)).tone == .tertiary)
  }

  @Test func aConflictWinsTheCornerOverAutoMerge() {
    let both = PullRequestMark(.sample(blocker: .conflicts, autoMergesWhenReady: true))
    #expect(both.corner == .conflicts)
    #expect(PullRequestMark(.sample(autoMergesWhenReady: true)).corner == .queued)
    #expect(
      PullRequestMark(.sample(blocker: .behindBase)).corner == nil,
      "said in the tooltip only",
    )
  }

  @Test func closedAndMergedCarryNoCorner() {
    #expect(PullRequestMark(.sample(state: .closed, blocker: .conflicts)).corner == nil)
    #expect(PullRequestMark(.sample(state: .merged, autoMergesWhenReady: true)).corner == nil)
    #expect(PullRequestMark(.sample(state: .merged)).tone == .merged)
  }
}
