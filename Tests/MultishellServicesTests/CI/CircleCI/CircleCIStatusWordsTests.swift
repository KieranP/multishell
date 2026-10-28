import Testing

@testable import MultishellServices

@Suite
struct CircleCIStatusWordsTests {
  @Test(
    arguments: [
      ("completed", "success", nil, CIRunStatus.passed),
      ("completed", "failed", nil, .failed),
      ("running", "failing", nil, .failed),
      ("completed", "canceled", nil, .cancelled),
      ("on_hold", nil, nil, .onHold),
      ("running", nil, nil, .running),
      ("created", nil, nil, .running),
      ("completed", "infrastructure_fail", nil, .failed),
      ("completed", "not_run", nil, .cancelled),
      ("queued", "not_running", nil, .running),
    ] as [(String?, String?, String?, CIRunStatus)]
  )
  func circleCIsOwnWordsReadAsTheirStatus(
    phase: String?,
    outcome: String?,
    current: String?,
    status: CIRunStatus,
  ) {
    #expect(
      CircleCIStatusWords.status(phase: phase, outcome: outcome, currentOutcome: current) == status
    )
  }

  @Test func aRerunsCurrentOutcomeWinsOverTheFirst() {
    #expect(
      CircleCIStatusWords.status(phase: "running", outcome: "success", currentOutcome: "failed")
        == .failed
    )
  }

  @Test func aRerunsCurrentOutcomeInAWordOnlyLooselyKnownStillWinsOverTheFirst() {
    #expect(
      CircleCIStatusWords.status(phase: "ended", outcome: "failed", currentOutcome: "rerunning")
        == .running
    )
  }

  @Test func wordsInAnotherCaseOrFormAreMatchedLoosely() {
    #expect(
      CircleCIStatusWords.status(phase: "COMPLETED", outcome: "SUCCESS", currentOutcome: nil)
        == .passed
    )
    #expect(
      CircleCIStatusWords.status(phase: nil, outcome: "Cancelled by user", currentOutcome: nil)
        == .cancelled
    )
    #expect(
      CircleCIStatusWords.status(phase: "awaiting_approval", outcome: nil, currentOutcome: nil)
        == .onHold
    )
  }

  @Test func aWordNeitherListKnowsIsNoStatus() {
    #expect(
      CircleCIStatusWords.status(phase: "completed", outcome: "mystery", currentOutcome: nil) == nil
    )
    #expect(CircleCIStatusWords.status(phase: nil, outcome: nil, currentOutcome: nil) == nil)
  }

  @Test func aPhaseThatIsItselfASettledOutcomeHasEnded() {
    #expect(CircleCIStatusWords.isFinished(phase: "errored", status: .failed))
    #expect(CircleCIStatusWords.isFinished(phase: "ended", status: .passed))
    #expect(
      !CircleCIStatusWords.isFinished(phase: "ended", status: .running),
      "a rerun under way",
    )
    #expect(!CircleCIStatusWords.isFinished(phase: "running", status: .failed))
    #expect(!CircleCIStatusWords.isFinished(phase: "failing", status: .failed))
    #expect(!CircleCIStatusWords.isFinished(phase: "created", status: .running))
  }

  @Test func aPhaseNeitherListKnowsLeavesTheOutcomeToSayWhetherItEnded() {
    #expect(CircleCIStatusWords.isFinished(phase: "complete", status: .passed))
    #expect(!CircleCIStatusWords.isFinished(phase: "complete", status: .running))
    #expect(!CircleCIStatusWords.isFinished(phase: "in_progress", status: .failed))
    #expect(!CircleCIStatusWords.isFinished(phase: "awaiting_approval", status: .cancelled))
  }

  @Test func aWordThatDeniesASettledOneIsNoStatusRatherThanItsOpposite() {
    #expect(
      CircleCIStatusWords.status(phase: nil, outcome: "unsuccessful", currentOutcome: nil) == nil
    )
    #expect(
      CircleCIStatusWords.status(phase: nil, outcome: "not_failed", currentOutcome: nil) == nil
    )
  }
}
