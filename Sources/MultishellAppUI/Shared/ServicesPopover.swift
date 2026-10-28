import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// A row's pull request as the panel's card shows it, and its CI run with its
/// workflows and jobs; the two headers' corner glyphs open them on their sites.
struct ServicesPopover: View {
  private static let width: Double = 280

  let model: AppModel
  let worktree: Worktree
  let theme: Theme

  var body: some View {
    let services = model.services(of: worktree)
    let metrics = model.metrics
    VStack(alignment: .leading, spacing: 10) {
      if let pullRequest = services.shownPullRequest {
        PullRequestSummary(
          model: model,
          worktree: worktree,
          pullRequest: pullRequest,
          theme: theme,
        )
      }
      if let outgrown = services.outgrownText {
        Text(outgrown).font(metrics.font(size: metrics.caption)).foregroundStyle(.secondary)
      }
      ciSection(services, metrics: metrics)
      if let problem = services.readProblemText {
        Text(problem)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      CreatePullRequestButton(model: model, worktree: worktree)
        .controlSize(.small)
    }
    .padding(12)
    .frame(width: Self.width, alignment: .leading)
    // A new run, or the shown one ending, while open lists other jobs.
    .task(id: services.ciRun) { await model.readCIWorkflows(of: worktree) }
  }

  @ViewBuilder
  private func ciSection(_ services: WorktreeServices, metrics: UIMetrics) -> some View {
    if let run = services.ciRun, let text = services.ciRunText {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          CIRunGlyph(
            status: run.status,
            theme: theme,
            palette: theme.header,
            size: metrics.serviceGlyphSize,
          )
          Text(text).font(metrics.font(size: metrics.caption, weight: .semibold))
          Spacer(minLength: 0)
          ExternalLinkButton(
            help: t("action.open-on", model.ciProviderName(of: worktree) ?? ""),
            size: metrics.glyph,
          ) {
            Task { await model.openCIRuns(of: worktree) }
          }
          .foregroundStyle(theme.header.textSecondary)
        }
        ForEach(Array((model.ciWorkflows(of: worktree) ?? []).enumerated()), id: \.offset) {
          _,
          workflow in
          workflowRows(workflow, metrics: metrics)
        }
      }
    }
  }

  private func workflowRows(_ workflow: CIWorkflow, metrics: UIMetrics) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        CIRunGlyph(
          status: workflow.status,
          theme: theme,
          palette: theme.header,
          size: metrics.small,
        )
        Text(workflow.name).font(metrics.font(size: metrics.caption))
      }
      .accessibilityElement(children: .combine)
      .accessibilityValue(AccessibilityText.ciStatus(workflow.status))
      ForEach(Array(workflow.jobs.enumerated()), id: \.offset) { _, job in
        HStack(spacing: 6) {
          CIRunGlyph(status: job.status, theme: theme, palette: theme.header, size: metrics.small)
          Text(job.name)
            .font(.system(size: metrics.badge, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.leading, metrics.small + 6)
        .accessibilityElement(children: .combine)
        .accessibilityValue(AccessibilityText.ciStatus(job.status))
      }
    }
  }
}
