import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIHandoffTests {
  private static func item(excerpt: String?, isRunFinished: Bool = true) -> CIHandoffItem {
    let run = CIRun.sample(id: "r1", status: .failed, isFinished: isRunFinished)
    let report = excerpt.map { text in
      CIFailureReport(excerpts: [CIFailureExcerpt(workflow: "build", job: "test", text: text)])
    }
    let workflow = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: "12", name: "test", status: .failed)],
    )
    return CIHandoffItem.items(of: run, workflows: [workflow], report: report)[0]
  }

  @Test func aJobIsHeadedByItsWorkflowAndQuotesItsReport() {
    let run = CIRun.sample(id: "r1", commit: "abc1234def", status: .failed)

    let entries = CIHandoff.entries(
      of: [Self.item(excerpt: "line one\nline two")],
      run: run,
      provider: "CircleCI",
      localTip: "abc1234def",
    )

    #expect(entries.map(\.heading) == ["build / test"])
    #expect(entries.first?.quote == ["line one", "line two"])
    #expect(entries.first?.caveat == nil)
    #expect(entries.first?.text == "Failed on CircleCI, job 12.")
  }

  @Test func aWorktreeOnAnotherCommitIsToldWhichCommitTheRunRanOn() {
    let run = CIRun.sample(id: "r1", commit: "abc1234def", status: .failed)

    let entries = CIHandoff.entries(
      of: [Self.item(excerpt: "failed")],
      run: run,
      provider: "CircleCI",
      localTip: "fff9999aaa",
    )

    #expect(entries.first?.caveat?.contains("abc1234") == true)
  }

  @Test func aLongReportKeepsItsLastEightyLinesAndSaysHowManyWentBefore() {
    let report = (1...100).map { "line \($0)" }.joined(separator: "\n")
    let run = CIRun.sample(id: "r1", status: .failed)

    let entry = CIHandoff.entries(
      of: [Self.item(excerpt: report)],
      run: run,
      provider: "CircleCI",
      localTip: nil,
    )[0]

    #expect(entry.quote.count == 80)
    #expect(entry.quote.first == "line 21")
    #expect(entry.caveat == "20 earlier lines cut.")
  }

  @Test func aJobWithItsReportUnreadSaysSo() {
    let run = CIRun.sample(id: "r1", status: .failed, isFinished: false)

    let entry = CIHandoff.entries(
      of: [Self.item(excerpt: nil, isRunFinished: false)],
      run: run,
      provider: "CircleCI",
      localTip: nil,
    )[0]

    #expect(entry.quote.isEmpty)
    #expect(entry.caveat == "Its report was not read yet: the run was still going.")
  }

  @Test func aFinishedRunsJobItsReadReportLeavesOutIsSaidToBeLeftOut() {
    let run = CIRun.sample(id: "r1", status: .failed, isFinished: true)
    let workflow = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: "12", name: "test", status: .failed)],
    )
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "lint", text: "lint failed")
    ])
    let item = CIHandoffItem.items(of: run, workflows: [workflow], report: report)[0]

    let entry = CIHandoff.entries(of: [item], run: run, provider: "CircleCI", localTip: nil)[0]

    #expect(entry.caveat == "The run's report says nothing of this job.")
  }

  @Test func aFinishedRunsJobWithItsReportUnreadSaysSoRatherThanThatItIsSilent() {
    let run = CIRun.sample(id: "r1", status: .failed, isFinished: true)
    let workflow = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: "12", name: "test", status: .failed)],
    )
    let item = CIHandoffItem.items(of: run, workflows: [workflow], report: nil)[0]

    let entry = CIHandoff.entries(of: [item], run: run, provider: "CircleCI", localTip: nil)[0]

    #expect(entry.caveat == "Its report was not read.")
  }
}
