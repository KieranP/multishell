import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessMergeActionTests {
  private func check(_ status: CIRunStatus, required: Bool = true) -> PullRequestCheck {
    PullRequestCheck(
      name: "build",
      workflow: "CI",
      status: status,
      isRequired: required,
      link: nil,
    )
  }

  @Test func aReadyPullRequestOffersMerge() {
    #expect(MergeReadiness(.sample(), checks: [check(.passed)]).mergeAction == .merge)
  }

  @Test func onlyRequiredChecksStillRunningOfferMergeWhenReady() {
    #expect(MergeReadiness(.sample(), checks: [check(.running)]).mergeAction == .mergeWhenReady)
    #expect(
      MergeReadiness(.sample(review: .required), checks: [check(.running)]).mergeAction == nil,
      "a person holds it back too",
    )
  }

  @Test func aCheckStillRunningWhileGitHubWorksOutConflictsStillOffersMergeWhenReady() {
    let readiness = MergeReadiness(.sample(hasConflictAnswer: false), checks: [check(.running)])
    #expect(readiness.mergeAction == .mergeWhenReady)
  }

  @Test func gitHubWorkingOutConflictsAloneOffersMergeWhenReady() {
    let readiness = MergeReadiness(.sample(hasConflictAnswer: false), checks: [check(.passed)])
    #expect(readiness.title(base: "main") == "Not ready to merge")
    #expect(readiness.mergeAction == .mergeWhenReady)
  }

  @Test func autoMergeAlreadyOnOffersItsCancelling() {
    let readiness = MergeReadiness(.sample(autoMergesWhenReady: true), checks: [check(.running)])
    #expect(readiness.mergeAction == .cancelAutoMerge)
  }

  @Test func aDraftAConflictOrChangesRequestedOffersNothing() {
    let ready = [check(.passed)]
    #expect(MergeReadiness(.sample(state: .draft), checks: ready).mergeAction == nil)
    #expect(MergeReadiness(.sample(blocker: .conflicts), checks: ready).mergeAction == nil)
    #expect(
      MergeReadiness(.sample(review: .changesRequested, isReadyToMerge: true), checks: ready)
        .mergeAction == nil
    )
  }

  @Test func aCardSayingNotReadyNeverOffersMergeWhateverGitHubSays() {
    let pastReview = MergeReadiness(
      .sample(review: .required, isReadyToMerge: true),
      checks: [check(.passed)],
    )
    let checksUnread = MergeReadiness(.sample(isReadyToMerge: true), checks: nil)
    #expect(pastReview.title(base: "main") == "Not ready to merge")
    #expect(pastReview.mergeAction == nil)
    #expect(checksUnread.mergeAction == nil)
  }

  @Test func aNewerChecksReadOutranksTheListsClean() {
    let ready = PullRequest.sample(isReadyToMerge: true)
    #expect(MergeReadiness(ready, checks: [check(.failed)]).mergeAction == nil)
    #expect(MergeReadiness(ready, checks: [check(.running)]).mergeAction == .mergeWhenReady)
  }

  @Test func aMergedOrClosedPullRequestOffersNothing() {
    #expect(MergeReadiness(.sample(state: .merged), checks: []).mergeAction == nil)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).mergeAction == nil)
  }
}
