import Testing

@testable import MultishellServices

@Suite
struct CircleCIFailureReportTextTests {
  @Test func eachJobsSectionIsFiledUnderItsWorkflowAndName() {
    let report = CircleCIFailureReportText.report(from: CircleCIFixtures.failureReport)

    #expect(report.excerpts.map(\.workflow) == ["prep_and_test", "prep_and_test"])
    #expect(report.excerpts.map(\.job) == ["playwright", "vitest"])
    #expect(
      report.excerpts.last?.text == """
        #### step 12: Vitest [exit: 1]

        FAIL src/theme.test.ts
        """
    )
  }

  @Test func aJobNamedWithBracketsKeepsThemAndLosesOnlyTheExecutionNote() {
    let report = CircleCIFailureReportText.report(
      from:
        "## workflow: build\n### job: build (arm64) (execution 0, 1 of 1 failed)\nboom\n### job: lint (arm64)\nbad\n"
    )

    #expect(report.excerpts.map(\.job) == ["build (arm64)", "lint (arm64)"])
  }

  @Test func aReportWithoutSectionsIsOneExcerptForNoJob() {
    let report = CircleCIFailureReportText.report(from: "Something went wrong\n")

    #expect(
      report.excerpts == [CIFailureExcerpt(workflow: nil, job: nil, text: "Something went wrong")]
    )
  }

  @Test func anEmptyReportHasNoExcerpts() {
    #expect(CircleCIFailureReportText.report(from: " \n").excerpts.isEmpty)
  }
}
