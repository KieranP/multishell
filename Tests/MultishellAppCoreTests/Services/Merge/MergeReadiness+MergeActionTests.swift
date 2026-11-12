import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessMergeActionTests {
  @Test func aReadyPullRequestOffersMerge() {
    #expect(MergeReadiness(.sample(), checks: [.sample(status: .passed)]).mergeAction == .merge)
  }

  @Test func onlyRequiredChecksStillRunningOfferMergeWhenReady() {
    #expect(
      MergeReadiness(.sample(), checks: [.sample(status: .running)]).mergeAction == .mergeWhenReady
    )
    #expect(
      MergeReadiness(.sample(review: .required), checks: [.sample(status: .running)]).mergeAction
        == nil,
      "a person holds it back too",
    )
  }

  @Test func aCheckStillRunningWhileGitHubWorksOutConflictsStillOffersMergeWhenReady() {
    let readiness = MergeReadiness(
      .sample(hasConflictAnswer: false),
      checks: [.sample(status: .running)],
    )
    #expect(readiness.mergeAction == .mergeWhenReady)
  }

  @Test func gitHubWorkingOutConflictsAloneOffersMergeWhenReady() {
    let readiness = MergeReadiness(
      .sample(hasConflictAnswer: false),
      checks: [.sample(status: .passed)],
    )
    #expect(!readiness.blockers.isEmpty)
    #expect(readiness.mergeAction == .mergeWhenReady)
  }

  @Test func autoMergeAlreadyOnOffersItsCancelling() {
    let readiness = MergeReadiness(
      .sample(autoMergesWhenReady: true),
      checks: [.sample(status: .running)],
    )
    #expect(readiness.mergeAction == .cancelAutoMerge)
  }

  @Test func aDraftAConflictOrChangesRequestedOffersNothing() {
    let ready = [PullRequestCheck.sample(status: .passed)]
    #expect(MergeReadiness(.sample(state: .draft), checks: ready).mergeAction == nil)
    #expect(MergeReadiness(.sample(blocker: .conflicts), checks: ready).mergeAction == nil)
    #expect(
      MergeReadiness(.sample(review: .changesRequested, isReadyToMerge: true), checks: ready)
        .mergeAction == nil
    )
  }

  @Test func aPullRequestHeldBackNeverOffersMergeWhateverGitHubSays() {
    let pastReview = MergeReadiness(
      .sample(review: .required, isReadyToMerge: true),
      checks: [.sample(status: .passed)],
    )
    let checksUnread = MergeReadiness(.sample(isReadyToMerge: true), checks: nil)
    #expect(!pastReview.blockers.isEmpty)
    #expect(pastReview.mergeAction == nil)
    #expect(checksUnread.mergeAction == nil)
  }

  @Test func aNewerChecksReadOutranksTheListsClean() {
    let ready = PullRequest.sample(isReadyToMerge: true)
    #expect(MergeReadiness(ready, checks: [.sample(status: .failed)]).mergeAction == nil)
    #expect(
      MergeReadiness(ready, checks: [.sample(status: .running)]).mergeAction == .mergeWhenReady
    )
  }

  @Test func aMergedOrClosedPullRequestOffersNothing() {
    #expect(MergeReadiness(.sample(state: .merged), checks: []).mergeAction == nil)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).mergeAction == nil)
  }
}
