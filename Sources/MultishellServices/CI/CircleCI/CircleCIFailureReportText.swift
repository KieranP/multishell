import Foundation

/// `circleci run get --failure-report`: a `## workflow:` heading over a
/// `### job:` one per failed job, whose heading ends in its execution.
enum CircleCIFailureReportText {
  private static let workflowHeading = "## workflow: "
  private static let jobHeading = "### job: "

  static func report(from text: String) -> CIFailureReport {
    var excerpts: [CIFailureExcerpt] = []
    var workflow: String?
    var job: String?
    var body: [Substring] = []
    func closeSection() {
      let text = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if !text.isEmpty {
        excerpts.append(CIFailureExcerpt(workflow: workflow, job: job, text: text))
      }
      body = []
    }
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
      if line.hasPrefix(workflowHeading) {
        closeSection()
        workflow = String(line.dropFirst(workflowHeading.count))
        job = nil
      } else if line.hasPrefix(jobHeading) {
        closeSection()
        job = jobName(line.dropFirst(jobHeading.count))
      } else {
        body.append(line)
      }
    }
    closeSection()
    return CIFailureReport(excerpts: excerpts)
  }

  /// `playwright (execution 0, 1 of 2 failed)` is the job `playwright`; a
  /// bracket of the job's own name, `build (arm64)`, stays.
  private static func jobName(_ heading: Substring) -> String {
    guard heading.hasSuffix(")"),
      let note = heading.range(of: " (execution ", options: .backwards)
    else { return String(heading) }
    return String(heading[..<note.lowerBound])
  }
}
