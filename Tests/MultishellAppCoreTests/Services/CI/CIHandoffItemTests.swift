import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIHandoffItemTests {
  private static let workflows = [
    CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [
        CIJob(id: "11", name: "lint", status: .passed),
        CIJob(id: "12", name: "test-macos", status: .failed),
      ],
    ),
    CIWorkflow(
      name: "docs",
      status: .failed,
      jobs: [CIJob(id: nil, name: "markdown-lint", status: .failed)],
    ),
  ]

  @Test func eachFailedJobIsAnItemWithItsPartOfTheReport() {
    let run = CIRun.sample(id: "r1", status: .failed)
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test-macos", text: "Expectation failed")
    ])

    let items = CIHandoffItem.items(of: run, workflows: Self.workflows, report: report)

    #expect(items.map(\.job?.name) == ["test-macos", "markdown-lint"])
    #expect(items.map(\.excerpt) == ["Expectation failed", nil])
    #expect(
      items.first?.candidate.id
        == .ciJob(runID: "r1", position: CIJobPosition(workflow: 0, job: 1), jobID: "12")
    )
  }

  @Test func reportTextNamingNoListedJobIsARunOutputItemAfterTheJobs() {
    let run = CIRun.sample(id: "r1", status: .failed)
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: nil, job: nil, text: "Config does not parse")
    ])

    let items = CIHandoffItem.items(of: run, workflows: [], report: report)

    #expect(items.map(\.heading) == ["Run output"])
    #expect(items.first?.excerpt == "Config does not parse")
  }

  @Test func aJobFailedWhileItsRunStillGoesAwaitsItsReport() {
    let going = CIRun.sample(id: "r1", status: .failed, isFinished: false)
    let ended = CIRun.sample(id: "r1", status: .failed, isFinished: true)

    let whileGoing = CIHandoffItem.items(of: going, workflows: Self.workflows, report: nil)
    let afterEnding = CIHandoffItem.items(of: ended, workflows: Self.workflows, report: nil)

    #expect(whileGoing.map(\.awaitsReport) == [true, true])
    #expect(afterEnding.map(\.awaitsReport) == [false, false])
  }

  @Test func twoSameNamedJobsOfSameNamedWorkflowsWithNoIDsAreTwoItems() {
    let run = CIRun.sample(id: "r1", status: .failed)
    let workflow = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: nil, name: "test", status: .failed)],
    )

    let items = CIHandoffItem.items(of: run, workflows: [workflow, workflow], report: nil)

    #expect(Set(items.map(\.candidate.id)).count == 2)
  }

  @Test func aJobTheReportNamesThoughItsStatusIsNotFailedCanBeSent() {
    let run = CIRun.sample(id: "r1", status: .failed)
    let workflow = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: "12", name: "test", status: .unknown)],
    )
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test", text: "boom")
    ])

    let items = CIHandoffItem.items(of: run, workflows: [workflow], report: report)

    #expect(items.map(\.excerpt) == ["boom"])
  }

  @Test func newRunOutputFromARerunOfTheSameRunIsANewItem() {
    let run = CIRun.sample(id: "r1", status: .failed)
    func output(_ text: String) -> CIHandoffItem? {
      let report = CIFailureReport(excerpts: [
        CIFailureExcerpt(workflow: nil, job: nil, text: text)
      ])
      return CIHandoffItem.items(of: run, workflows: [], report: report).first
    }

    #expect(output("bad config")?.candidate.id != output("still bad")?.candidate.id)
  }

  @Test func aPassingJobSharingAFailedOnesNamesIsNoItem() {
    let run = CIRun.sample(id: "r1", status: .failed)
    let failed = CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [CIJob(id: "1", name: "test", status: .failed)],
    )
    let rerun = CIWorkflow(
      name: "build",
      status: .passed,
      jobs: [CIJob(id: "2", name: "test", status: .passed)],
    )
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test", text: "boom")
    ])

    let items = CIHandoffItem.items(of: run, workflows: [failed, rerun], report: report)

    #expect(items.map(\.job?.id) == ["1"])
  }

  @Test func aRunThatPassedHasNothingToSend() {
    let run = CIRun.sample(id: "r1", status: .passed)
    let workflow = CIWorkflow(
      name: "build",
      status: .passed,
      jobs: [CIJob(id: "1", name: "flaky", status: .failed)],
    )

    #expect(CIHandoffItem.items(of: run, workflows: [workflow], report: nil).isEmpty)
  }

  @Test func aCancelledRunsFailedJobCanBeSent() {
    let run = CIRun.sample(id: "r1", status: .cancelled)
    let workflow = CIWorkflow(
      name: "build",
      status: .cancelled,
      jobs: [CIJob(id: "1", name: "test", status: .failed)],
    )

    let items = CIHandoffItem.items(of: run, workflows: [workflow], report: nil)

    #expect(items.map(\.job?.id) == ["1"])
  }
}
