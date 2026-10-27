import Testing

@testable import MultishellServices

@Suite
struct CIFailureReportTests {
  private let workflows = [
    CIWorkflow(
      name: "build",
      status: .failed,
      jobs: [
        CIJob(id: "1", name: "test", status: .failed),
        CIJob(id: "2", name: "lint", status: .passed),
      ],
    )
  ]

  @Test func anExcerptIsPlacedUnderTheJobOfItsWorkflow() {
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test", text: "boom"),
      CIFailureExcerpt(workflow: "deploy", job: "lint", text: "elsewhere"),
    ])

    #expect(report.excerpt(ofJob: "test", inWorkflow: "build") == "boom")
    #expect(report.excerpt(ofJob: "lint", inWorkflow: "build") == nil)
  }

  @Test func whatNoListedJobAccountsForIsLeftUnplaced() {
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test", text: "boom"),
      CIFailureExcerpt(workflow: "deploy", job: "ship", text: "elsewhere"),
      CIFailureExcerpt(workflow: nil, job: nil, text: "loose"),
    ])

    #expect(report.unplaced(among: workflows) == ["elsewhere", "loose"])
  }
}
