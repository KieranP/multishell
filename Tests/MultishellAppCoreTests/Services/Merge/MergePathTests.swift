import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct MergePathTests {
  @Test func theStepsAreTheDraftConflictsBaseChecksThenTheReview() {
    let path = MergePath.sample(
      .sample(state: .draft, review: .required, blocker: .behindBase),
      checks: [.sample(status: .failed)],
    )
    #expect(path.steps.map(\.kind) == [.draft, .conflicts, .behindBase, .checks, .review])
    #expect(path.steps.map(\.status) == [.onHold, .passed, .failed, .failed, .onHold])
  }

  @Test func aRuleIsTheLastStepAndOnlyWhereNothingElseHoldsItBack() {
    let alone = MergePath.sample(
      .sample(review: .approved, blocker: .blocked),
      checks: [.sample()],
    )
    let beside = MergePath.sample(.sample(review: .required, blocker: .blocked), checks: [])
    #expect(alone.steps.map(\.kind) == [.conflicts, .checks, .review, .blockedByRules])
    #expect(!beside.steps.contains { $0.kind == .blockedByRules })
  }

  @Test func theConflictsStepWarnsOnlyWhereItConflicts() {
    let conflicting = MergePath.sample(.sample(blocker: .conflicts), checks: [])
    let unchecked = MergePath.sample(.sample(hasConflictAnswer: false), checks: [])
    #expect(conflicting.steps.filter(\.warnsOfConflicts).map(\.kind) == [.conflicts])
    #expect(unchecked.steps.first?.status == .running)
    #expect(!unchecked.steps.contains { $0.warnsOfConflicts })
  }

  @Test func everyCheckIsListedInTheHostsOrder() {
    let checks: [PullRequestCheck] = [
      .sample(name: "lint", isRequired: false),
      .sample(name: "build", isRequired: true),
    ]
    #expect(MergePath.sample(.sample(), checks: checks).checks == checks)
  }

  @Test func theChecksStepTakesTheWorstRequiredCheck() {
    let failing = MergePath.sample(
      .sample(),
      checks: [.sample(status: .running), .sample(status: .failed)],
    )
    let running = MergePath.sample(
      .sample(),
      checks: [
        .sample(status: .running), .sample(name: "lint", status: .failed, isRequired: false),
      ],
    )
    let skipped = MergePath.sample(.sample(), checks: [.sample(status: .cancelled)])
    #expect(failing.steps.first { $0.kind == .checks }?.status == .failed)
    #expect(running.steps.first { $0.kind == .checks }?.status == .running)
    #expect(skipped.steps.first { $0.kind == .checks }?.status == .passed)
  }

  @Test func aPullRequestWithNoChecksHasNoChecksStep() {
    #expect(!MergePath.sample(.sample(), checks: []).steps.contains { $0.kind == .checks })
  }

  @Test func checksNotYetReadAreAStepOfTheirOwn() {
    let path = MergePath.sample(.sample(), checks: nil)
    #expect(path.steps.contains(MergePath.Step(kind: .checksNotRead, status: .running)))
    #expect(!path.steps.contains { $0.kind == .checks })
  }

  @Test func aFailedReadOfChecksAlreadyReadIsANoteNotAStep() {
    let path = MergePath.sample(
      .sample(),
      checks: [.sample()],
      checksReadProblem: "gh pr checks: HTTP 502",
    )
    #expect(
      path.staleChecksNote
        == "The checks shown may be out of date. Last read: gh pr checks: HTTP 502"
    )
    #expect(!path.steps.contains { $0.kind == .checksNotRead })
    #expect(
      MergePath.sample(.sample(), checks: nil, checksReadProblem: "x").staleChecksNote == nil
    )
  }

  @Test func aFailedReadAfterOneThatListedNoChecksDoesNotSpeakOfChecksShown() {
    let path = MergePath.sample(.sample(), checks: [], checksReadProblem: "HTTP 502")
    #expect(path.staleChecksNote == "Checks not read again: HTTP 502")
  }

  @Test func aSettledPullRequestListsNoConflictsAndOnlyAnApproval() {
    let closed = MergePath.sample(.sample(state: .closed, review: .required), checks: [])
    let merged = MergePath.sample(.sample(state: .merged, review: .approved), checks: [])
    #expect(closed.steps.isEmpty)
    #expect(merged.steps == [MergePath.Step(kind: .review, status: .passed)])
  }

  @Test func aSettledPullRequestTheHostStillCallsBlockedOrBehindListsNoBaseOrRule() {
    let closed = MergePath.sample(
      .sample(state: .closed, review: .approved, blocker: .blocked),
      checks: [],
    )
    let merged = MergePath.sample(.sample(state: .merged, blocker: .behindBase), checks: [])
    #expect(closed.steps == [MergePath.Step(kind: .review, status: .passed)])
    #expect(merged.steps.isEmpty)
  }

  @Test func theEndOffersTheMergeActionWhereThereIsOne() {
    let ready = MergePath.sample(.sample(review: .approved), checks: [.sample()])
    let running = MergePath.sample(.sample(), checks: [.sample(status: .running)])
    let queued = MergePath.sample(
      .sample(autoMergesWhenReady: true),
      checks: [.sample(status: .running)],
    )
    #expect(ready.end == .offers(.merge))
    #expect(running.end == .offers(.mergeWhenReady))
    #expect(queued.end == .offers(.cancelAutoMerge))
  }

  @Test func aMergeTheHostTookOffersNothingThoughChecksStillRun() {
    let path = MergePath.sample(.sample(), checks: [.sample(status: .running)], isMergeTaken: true)
    #expect(path.end == .taken)
  }

  @Test func aHeldPathCountsTheStepsLeftToClear() {
    let path = MergePath.sample(
      .sample(review: .required, blocker: .conflicts),
      checks: [.sample(status: .passed)],
    )
    #expect(path.end == .waits(.steps(2)))
  }

  @Test func aPathLeftOnlyToTheChecksReadWaitsOnItReadOrFailed() {
    #expect(MergePath.sample(.sample(), checks: nil).end == .waits(.checksRead))
    #expect(
      MergePath.sample(.sample(), checks: nil, checksReadProblem: "x").end == .waits(.checksRead)
    )
  }

  @Test func aSettledPullRequestEndsOnWhatBecameOfIt() {
    #expect(MergePath.sample(.sample(state: .closed), checks: []).end == .closed)
    #expect(
      MergePath.sample(.sample(state: .merged), checks: [], isOutgrown: true).end
        == .merged(isOutgrown: true)
    )
    #expect(
      MergePath.sample(.sample(state: .merged), checks: []).end == .merged(isOutgrown: false)
    )
  }
}
