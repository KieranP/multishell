import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessTests {
  @Test func anApprovedPullRequestWhoseRequiredChecksPassedIsReady() {
    let readiness = MergeReadiness(
      .sample(review: .approved),
      checks: [
        .sample(name: "build", status: .passed, isRequired: true),
        .sample(name: "lint", status: .passed, isRequired: false),
      ],
    )
    #expect(readiness.verdict == .ready)
    #expect(readiness.blockers == [])
    #expect(readiness.detail(base: "main") == "Every required check passed")
  }

  @Test func onlyAConflictRowThatConflictsWarnsRatherThanFails() {
    let conflicting = MergeReadiness(
      .sample(blocker: .conflicts),
      checks: [.sample(name: "build", status: .failed, isRequired: true)],
    )
    let clear = MergeReadiness(.sample(), checks: [])
    #expect(conflicting.requirements.filter(\.warnsOfConflicts).map(\.kind) == [.conflicts])
    #expect(clear.requirements.contains { $0.warnsOfConflicts } == false)
  }

  @Test func aFailingCheckNobodyRequiredStillLetsItMerge() {
    let readiness = MergeReadiness(
      .sample(),
      checks: [.sample(name: "lint", status: .failed, isRequired: false)],
    )
    #expect(readiness.verdict == .readyWithOptionalFailures)
  }

  @Test func whatHoldsItBackIsListedMostPressingFirst() {
    let readiness = MergeReadiness(
      .sample(review: .required, blocker: .conflicts),
      checks: [
        .sample(name: "test", status: .failed, isRequired: true),
        .sample(name: "build", status: .running, isRequired: true),
        .sample(name: "lint", status: .failed, isRequired: false),
      ],
    )
    #expect(readiness.verdict == .notReady)
    #expect(
      readiness.blockers == [.conflicts, .failingChecks(1), .reviewRequired, .pendingChecks(1)]
    )
    #expect(
      readiness.detail(base: "main")
        == "Conflicts with main · 1 required check failed · Waiting on a review · 1 required check running"
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

  @Test func theRowsAreTheReviewTheConflictsThenRequiredChecksThenTheRest() {
    let readiness = MergeReadiness(
      .sample(review: .approved),
      checks: [
        .sample(name: "lint", status: .passed, isRequired: false),
        .sample(name: "build", status: .passed, isRequired: true),
      ],
    )
    #expect(
      readiness.requirements.map { $0.name(base: "main") }
        == ["Review approved", "No conflicts with main", "CI / build", "CI / lint"]
    )
  }

  @Test func noReviewRowWhereTheBaseNeedsNone() {
    let readiness = MergeReadiness(.sample(review: .notRequired), checks: [])
    #expect(readiness.requirements.map(\.kind) == [.conflicts])
  }

  @Test func aMergedOrClosedPullRequestHasNoVerdictBeyondThat() {
    #expect(
      MergeReadiness(.sample(state: .merged), checks: []).title(base: "main") == "Merged into main"
    )
    #expect(MergeReadiness(.sample(state: .closed), checks: []).verdict == .closed)
    #expect(MergeReadiness(.sample(state: .closed), checks: []).detail(base: "main") == nil)
  }

  @Test func aDraftIsNotReady() {
    let readiness = MergeReadiness(.sample(state: .draft), checks: [])
    #expect(readiness.verdict == .notReady)
    #expect(readiness.blockers == [.draft])
  }

  @Test func aPullRequestNotYetCheckedForConflictsIsNotReady() {
    let readiness = MergeReadiness(.sample(hasConflictAnswer: false), checks: [])
    #expect(readiness.verdict == .notReady)
    #expect(readiness.blockers == [.conflictsUnchecked])
    #expect(readiness.requirements.first { $0.kind == .conflicts }?.status == .running)
    #expect(
      readiness.requirements.first { $0.kind == .conflicts }?.name(base: "main")
        == "Checking for conflicts with main"
    )
  }

  @Test func aMergedOrClosedPullRequestListsNoConflictsRow() {
    let merged = MergeReadiness(.sample(state: .merged, hasConflictAnswer: false), checks: [])
    #expect(!merged.requirements.contains { $0.kind == .conflicts })
  }

  @Test func onlyARequiredCheckCarriesTheRequiredTag() {
    let readiness = MergeReadiness(
      .sample(review: .required),
      checks: [
        .sample(name: "build", status: .passed, isRequired: true),
        .sample(name: "lint", status: .passed, isRequired: false),
      ],
    )
    #expect(readiness.requirements.map(\.showsRequiredTag) == [false, false, true, false])
  }

  @Test func onlyACheckWithAPageOfItsOwnOpensAtAClick() {
    let linked = PullRequestCheck.sample(
      link: URL(string: "https://github.com/me/demo/actions/runs/1")
    )
    let readiness = MergeReadiness(
      .sample(review: .required, blocker: .conflicts),
      checks: [linked, .sample(name: "lint", isRequired: false)],
    )
    #expect(readiness.requirements.compactMap(\.openableCheck) == [linked])
  }
}
