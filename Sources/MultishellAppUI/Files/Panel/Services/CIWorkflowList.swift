import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A run's workflows and their jobs, a job opening on the provider at a click,
/// and under each failed job what the run's failure report says of it.
struct CIWorkflowList: View {
  let model: AppModel
  let worktree: Worktree
  let run: CIRun
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let workflows = model.ciWorkflows(ofRun: run) ?? []
    let report = model.failureReport(of: run)
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(workflows.enumerated()), id: \.offset) {
        _,
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
        ForEach(Array(workflow.jobs.enumerated()), id: \.offset) { _, job in
          CIJobRow(model: model, worktree: worktree, job: job, theme: theme)
          if let excerpt = report?.excerpt(ofJob: job.name, inWorkflow: workflow.name) {
            CIFailureExcerptView(text: excerpt, theme: theme, metrics: metrics)
              .padding(.leading, metrics.servicePageJobIndent)
          }
        }
      }
      ForEach(Array((report?.unplaced(among: workflows) ?? []).enumerated()), id: \.offset) {
        _,
        excerpt in
        CIFailureExcerptView(text: excerpt, theme: theme, metrics: metrics)
      }
    }
    .task(id: run.id) { await model.readCIRunDetails(of: run, for: worktree) }
  }
}
