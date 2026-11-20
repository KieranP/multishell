import MultishellCore
import MultishellServices

/// What the CI page can send of its newest run: each failed job, and the report's
/// text no listed job holds; see Docs/design/services/send-feedback.md.
public struct CIHandoffItem: Hashable, Sendable {
  public let candidate: HandoffCandidate
  /// `nil` for the report's text that names no listed job.
  let workflow: String?
  let job: CIJob?
  /// `nil` until the report is read, which waits for the run to end.
  let excerpt: String?
  /// "build / test", or "Run output" for the text no job holds.
  public var heading: String {
    guard let workflow, let job else { return t("handoff.run-output") }
    return "\(workflow) / \(job.name)"
  }

  /// A job failed while its run still goes: its report is read once it ends.
  public var awaitsReport: Bool { excerpt == nil && !isRunFinished }
  private let isRunFinished: Bool
  /// Whether the run's report was read: one read that names no job here differs
  /// from one never read, a cancelled run's or a failed read.
  let isReportRead: Bool
  /// Where the page lists it, two workflows being able to share a name; `nil`
  /// for the report's text that names no listed job.
  let position: CIJobPosition?

  /// In the page's order: the failed jobs, and any the report speaks of, then
  /// the report's `unplaced` text, which can be the only failure, a config error.
  static func items(
    of run: CIRun,
    workflows: [CIWorkflow],
    report: CIFailureReport?,
    unplaced: [String],
  ) -> [Self] {
    guard run.status != .passed else { return [] }
    var items: [Self] = workflows.enumerated().flatMap { workflowIndex, workflow in
      workflow.jobs.enumerated().compactMap { jobIndex, job -> Self? in
        let excerpt = report?.excerpt(ofJob: job.name, inWorkflow: workflow.name)
        // A job the report speaks of shows its text under its row, so it can be sent
        // whatever unclear status it has; one that passed shares a failed one's names.
        guard job.status == .failed || (excerpt != nil && job.status != .passed) else {
          return nil
        }
        let position = CIJobPosition(workflow: workflowIndex, job: jobIndex)
        return Self(
          candidate: HandoffCandidate(
            .ciJob(runID: run.id, position: position, jobID: job.id, isReportRead: report != nil)
          ),
          workflow: workflow.name,
          job: job,
          excerpt: excerpt,
          isRunFinished: run.isFinished,
          isReportRead: report != nil,
          position: position,
        )
      }
    }
    if !unplaced.isEmpty {
      let text = unplaced.joined(separator: "\n\n")
      items.append(
        Self(
          candidate: HandoffCandidate(.ciRunOutput(runID: run.id, textHash: text.hashValue)),
          workflow: nil,
          job: nil,
          excerpt: text,
          isRunFinished: run.isFinished,
          isReportRead: true,
          position: nil,
        )
      )
    }
    return items
  }
}
