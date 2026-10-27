import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIRunWordingTests {
  @Test func aRunIsHeadedByItsSubjectElseItsShortCommit() {
    let named = CIRun(
      id: "a",
      branch: "feat",
      commit: "9f2bcef611",
      subject: "Fix the build",
      status: .passed,
      isFinished: true,
      createdAt: nil,
    )
    let unnamed = CIRun(
      id: "b",
      branch: "feat",
      commit: "9f2bcef611",
      subject: nil,
      status: .passed,
      isFinished: true,
      createdAt: nil,
    )
    #expect(named.headline == "Fix the build")
    #expect(unnamed.headline == "9f2bcef")
  }

  @Test func aRunSaysNothingOfTheLocalTipWhereItIsUnknown() {
    let run = CIRun.sample(commit: "9f2bcef611")
    #expect(run.startText(localTip: nil) == "")
    #expect(run.startText(localTip: "other0000") == "not the local tip")
  }
}
