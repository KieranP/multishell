import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessTests {
  @Test func anApprovedPullRequestWhoseRequiredChecksPassedIsHeldBackByNothing() {
    let readiness = MergeReadiness(
      .sample(review: .approved),
      checks: [
        .sample(name: "build", status: .passed, isRequired: true),
        .sample(name: "lint", status: .passed, isRequired: false),
      ],
    )
    #expect(readiness.blockers == [])
  }

  @Test func aFailingCheckNobodyRequiredStillLetsItMerge() {
    let readiness = MergeReadiness(
      .sample(),
      checks: [.sample(name: "lint", status: .failed, isRequired: false)],
    )
    #expect(readiness.blockers == [])
    #expect(readiness.mergeAction == .merge)
  }

  @Test func conflictsARequiredCheckFailingOrRunningAndAReviewEachHoldItBack() {
    let readiness = MergeReadiness(
      .sample(review: .required, blocker: .conflicts),
      checks: [
        .sample(name: "test", status: .failed, isRequired: true),
        .sample(name: "build", status: .running, isRequired: true),
        .sample(name: "lint", status: .failed, isRequired: false),
      ],
    )
    #expect(
      readiness.blockers == [.conflicts, .failingChecks, .reviewRequired, .pendingChecks]
    )
  }

  @Test func theHostsOwnBlockIsSaidOnlyWhereNothingElseAccountsForIt() {
    #expect(
      MergeReadiness(.sample(blocker: .blocked), checks: []).blockers == [.blockedByRules]
    )
    #expect(
      MergeReadiness(.sample(review: .required, blocker: .blocked), checks: []).blockers
        == [.reviewRequired]
    )
  }

  @Test func aDraftIsHeldBack() {
    #expect(MergeReadiness(.sample(state: .draft), checks: []).blockers == [.draft])
  }

  @Test func aPullRequestNotYetCheckedForConflictsIsHeldBack() {
    let readiness = MergeReadiness(.sample(hasConflictAnswer: false), checks: [])
    #expect(readiness.blockers == [.conflictsUnchecked])
  }

  @Test func checksNotYetReadHoldItBackUntilARead() {
    #expect(MergeReadiness(.sample(), checks: nil).blockers == [.checksNotRead])
  }
}
