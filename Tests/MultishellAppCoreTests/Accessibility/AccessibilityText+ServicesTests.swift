import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct AccessibilityTextServicesTests {
  @Test func eachRunStatusIsSaidAsTheGlyphDrawsIt() {
    #expect(AccessibilityText.ciStatus(.cancelled) == "cancelled")
    #expect(AccessibilityText.ciStatus(.failed) == "failed")
    #expect(AccessibilityText.ciStatus(.onHold) == "on hold")
    #expect(AccessibilityText.ciStatus(.passed) == "passed")
    #expect(AccessibilityText.ciStatus(.running) == "running")
  }

  @Test func anEarlierRunSaysItsStatusThenWhetherItIsOpen() {
    #expect(AccessibilityText.ciStatus(.failed, isExpanded: false) == "failed, collapsed")
  }

  @Test func aCheckSaysItsStatusWhereAReviewOrConflictsNameItAlready() {
    let check = PullRequestCheck(
      name: "build",
      workflow: "ci",
      status: .failed,
      isRequired: true,
      link: nil,
    )
    let failingCheck = MergeReadiness.Requirement(
      kind: .check(check),
      status: .failed,
      isRequired: true,
    )
    let review = MergeReadiness.Requirement(kind: .review, status: .failed, isRequired: true)
    let conflicts = MergeReadiness.Requirement(kind: .conflicts, status: .failed, isRequired: true)

    #expect(AccessibilityText.requirementStatus(failingCheck) == "failed")
    #expect(AccessibilityText.requirementStatus(review) == nil)
    #expect(AccessibilityText.requirementStatus(conflicts) == nil)
  }
}
