import Testing

@testable import MultishellServices

@Suite
struct CIRunTests {
  private let run = CIRun(
    id: "r",
    branch: "feat",
    commit: "9f2bcef",
    subject: nil,
    status: .passed,
    isFinished: true,
    createdAt: nil,
  )

  @Test func aShortCommitMatchesTheFullOneItStartsAndNothingElse() {
    #expect(run.ran("9f2bcef611313c5e74b18f3fa2ea96498e378cde"))
    #expect(run.ran("9f2bcef"))
    #expect(!run.ran("9f2bcee611313c5e74b18f3fa2ea96498e378cde"))
    #expect(!run.ran(nil))
    #expect(!run.ran("9f2"), "too short to say")
  }

  @Test func aRunIsUnderWayUntilItEndsExceptWhileItWaitsOnAnApproval() {
    func run(_ status: CIRunStatus, isFinished: Bool) -> CIRun {
      CIRun(
        id: "r",
        branch: "feat",
        commit: "9f2bcef",
        subject: nil,
        status: status,
        isFinished: isFinished,
        createdAt: nil,
      )
    }
    #expect(run(.running, isFinished: false).isUnderWay)
    #expect(run(.failed, isFinished: false).isUnderWay, "one job down, the rest still going")
    #expect(!run(.onHold, isFinished: false).isUnderWay)
    #expect(!run(.failed, isFinished: true).isUnderWay)
  }

  @Test func theShortCommitIsGitsShortestAbbreviation() {
    let long = CIRun(
      id: "r",
      branch: "feat",
      commit: "9f2bcef611313c5e74b18f3fa2ea96498e378cde",
      subject: nil,
      status: .passed,
      isFinished: true,
      createdAt: nil,
    )
    #expect(long.shortCommit == "9f2bcef")
  }
}
