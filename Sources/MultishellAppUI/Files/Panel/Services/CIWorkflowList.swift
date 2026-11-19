import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A run's workflows and jobs, under each failed job what its report says, and
/// on the newest run each failure's checkbox; see services/send-feedback.md.
struct CIWorkflowList: View {
  let model: AppModel
  let worktree: Worktree
  let run: CIRun
  /// The run's workflows, report text and, on the newest run, what can be sent.
  let listing: CIWorkflowListing
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(listing.workflows.enumerated()), id: \.offset) {
        workflowIndex,
        workflow in
        HStack(spacing: 7) {
          CIRunGlyph(
            status: workflow.status,
            theme: theme,
            palette: theme.filesPanel,
            size: metrics.servicePageRowGlyphSize,
          )
          Text(workflow.name)
            .font(metrics.font(size: metrics.secondary, weight: .semibold))
            .foregroundStyle(theme.filesPanel.text)
            .lineLimit(1)
        }
        .padding(.horizontal, UIMetrics.servicePageSideInset)
        .frame(height: metrics.paneRowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityValue(AccessibilityText.ciStatus(workflow.status))
        ForEach(Array(workflow.jobs.enumerated()), id: \.offset) { jobIndex, job in
          let position = CIJobPosition(workflow: workflowIndex, job: jobIndex)
          let item = listing.item(at: position)
          CIJobRow(
            model: model,
            worktree: worktree,
            job: job,
            showsHandoffSlot: listing.showsHandoffSlot,
            candidate: item?.candidate,
            theme: theme,
          )
          if let excerpt = listing.excerpt(ofJobAt: position) {
            CIFailureExcerptView(text: excerpt, theme: theme, metrics: metrics)
              .padding(.leading, metrics.servicePageJobIndent)
          } else if item?.awaitsReport == true {
            Text(t("panel.ci-report-after-run"))
              .font(metrics.font(size: metrics.caption))
              .foregroundStyle(theme.filesPanel.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.leading, UIMetrics.servicePageSideInset + 2 * metrics.servicePageJobIndent)
              .padding(.trailing, UIMetrics.servicePageSideInset)
              .padding(.bottom, 4)
          }
        }
      }
      if let output = listing.runOutput {
        CIRunOutputRow(model: model, worktree: worktree, output: output, theme: theme)
      }
      ForEach(Array(listing.unplacedExcerpts.enumerated()), id: \.offset) {
        _,
        excerpt in
        CIFailureExcerptView(text: excerpt, theme: theme, metrics: metrics)
      }
      if let problem = model.ciRunDetailProblem(ofRun: run, for: worktree) {
        ServicePageNote(text: problem, theme: theme, metrics: metrics)
      }
    }
    .task(id: run.id) { await model.readCIRunDetails(of: run, for: worktree) }
  }
}
