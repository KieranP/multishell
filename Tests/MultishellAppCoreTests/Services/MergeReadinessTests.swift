import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergeReadinessTests {
  private func check(_ name: String, _ status: CIRunStatus, required: Bool) -> PullRequestCheck {
    PullRequestCheck(name: name, workflow: "CI", status: status, isRequired: required, link: nil)
  }

  @Test func anApprovedPullRequestWhoseRequiredChecksPassedIsReady() {
    let readiness = MergeReadiness(
      .sample(review: .approved),
      checks: [check("build", .passed, required: true), check("lint", .passed, required: false)],
    )
    #expect(readiness.verdict == .ready)
    #expect(readiness.blockers == [])
    #expect(readiness.detail(base: "main") == "Every required check passed")
  }

  @Test func onlyAConflictRowThatConflictsWarnsRatherThanFails() {
    let conflicting = MergeReadiness(
      .sample(blocker: .conflicts),
      checks: [check("build", .failed, required: true)],
    )
    let clear = MergeReadiness(.sample(), checks: [])
    #expect(conflicting.requirements.filter(\.warnsOfConflicts).map(\.kind) == [.conflicts])
    #expect(clear.requirements.contains { $0.warnsOfConflicts } == false)
  }

  @Test func aFailingCheckNobodyRequiredStillLetsItMerge() {
    let readiness = MergeReadiness(.sample(), checks: [check("lint", .failed, required: false)])
    #expect(readiness.verdict == .readyWithOptionalFailures)
  }

  @Test func whatHoldsItBackIsListedMostPressingFirst() {
    let readiness = MergeReadiness(
      .sample(review: .required, blocker: .conflicts),
      checks: [
        check("test", .failed, required: true),
        check("build", .running, required: true),
        check("lint", .failed, required: false),
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
      checks: [check("lint", .passed, required: false), check("build", .passed, required: true)],
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
      checks: [check("build", .passed, required: true), check("lint", .passed, required: false)],
    )
    #expect(readiness.requirements.map(\.showsRequiredTag) == [false, false, true, false])
  }
}
