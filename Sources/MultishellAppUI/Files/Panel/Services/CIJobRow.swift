import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One job of a workflow, which opens on the provider at a click.
struct CIJobRow: View {
  let model: AppModel
  let worktree: Worktree
  let job: CIJob
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    Button {
      Task { await model.openCIJob(job, of: worktree) }
    } label: {
      HStack(spacing: 7) {
        CIRunGlyph(
          status: job.status,
          theme: theme,
          palette: theme.filesPanel,
          size: metrics.servicePageRowGlyphSize,
        )
        Text(job.name)
          .font(.system(size: metrics.caption, design: .monospaced))
          .foregroundStyle(
            job.status.drawsAttention ? theme.filesPanel.text : theme.filesPanel.textSecondary
          )
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: 0)
      }
      .padding(.leading, UIMetrics.servicePageSideInset + metrics.servicePageJobIndent)
      .padding(.trailing, UIMetrics.servicePageSideInset)
      .frame(height: metrics.paneRowHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(job.id == nil)
    .accessibilityValue(AccessibilityText.ciStatus(job.status))
    .help(t("action.open-job", job.name))
  }
}
