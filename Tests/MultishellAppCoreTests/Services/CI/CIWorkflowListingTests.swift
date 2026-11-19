import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIWorkflowListingTests {
  private static let run = CIRun.sample(id: "r1", status: .failed)

  private static func listing(
    _ workflows: [CIWorkflow],
    report: CIFailureReport?,
    sending: Bool,
  ) -> CIWorkflowListing {
    CIWorkflowListing(run: run, workflows: workflows, report: report, sendsFailures: sending)
  }

  @Test func aJobIsFoundByItsPlaceThoughTwoWorkflowsShareAName() {
    let workflows = [
      CIWorkflow(
        name: "build",
        status: .passed,
        jobs: [CIJob(id: "1", name: "test", status: .passed)],
      ),
      CIWorkflow(
        name: "build",
        status: .failed,
        jobs: [CIJob(id: "2", name: "test", status: .failed)],
      ),
    ]

    let listing = Self.listing(workflows, report: nil, sending: true)

    #expect(listing.item(at: CIJobPosition(workflow: 0, job: 0)) == nil)
    #expect(listing.item(at: CIJobPosition(workflow: 1, job: 0))?.job?.id == "2")
    #expect(listing.showsHandoffSlot)
  }

  @Test func aRunWhoseOnlyItemIsRunOutputKeepsNoSlotOnItsJobRows() {
    let workflows = [
      CIWorkflow(
        name: "build",
        status: .passed,
        jobs: [CIJob(id: "1", name: "lint", status: .passed)],
      )
    ]
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: nil, job: nil, text: "bad config")
    ])

    let listing = Self.listing(workflows, report: report, sending: true)

    #expect(!listing.showsHandoffSlot)
    #expect(listing.runOutput?.excerpt == "bad config")
    #expect(listing.unplacedExcerpts == ["bad config"])
  }

  @Test func anEarlierRunReadsItsReportForEachJobAndSendsNothing() {
    let workflows = [
      CIWorkflow(
        name: "build",
        status: .failed,
        jobs: [CIJob(id: "1", name: "test", status: .failed)],
      )
    ]
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: "build", job: "test", text: "boom")
    ])

    let listing = Self.listing(workflows, report: report, sending: false)

    #expect(listing.excerpt(ofJobAt: CIJobPosition(workflow: 0, job: 0)) == "boom")
    #expect(!listing.showsHandoffSlot)
  }

  @Test func theNewestRunShowsEachUnplacedExcerptInABoxOfItsOwn() {
    let report = CIFailureReport(excerpts: [
      CIFailureExcerpt(workflow: nil, job: nil, text: "first"),
      CIFailureExcerpt(workflow: nil, job: nil, text: "second"),
    ])

    let listing = Self.listing([], report: report, sending: true)

    #expect(listing.unplacedExcerpts == ["first", "second"])
  }
}
