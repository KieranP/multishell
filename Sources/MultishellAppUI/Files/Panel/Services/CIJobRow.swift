import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One job of a workflow, which opens on the provider at a click, and on the
/// newest run a failed one's checkbox or sent bubble at its trailing edge.
struct CIJobRow: View {
  let model: AppModel
  let worktree: Worktree
  let job: CIJob
  /// On the newest run every job keeps the trailing slot, so the column holds.
  let showsHandoffSlot: Bool
  /// What the slot sends, for a failed job of the newest run.
  let candidate: HandoffCandidate?
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    // The slot sits over the button, so the whole row's height still opens the job.
    let slotClearance = showsHandoffSlot ? metrics.handoffSlotWidth + 7 : 0
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
      .padding(.trailing, UIMetrics.servicePageSideInset + slotClearance)
      .frame(height: metrics.paneRowHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(job.id == nil)
    .accessibilityValue(AccessibilityText.ciStatus(job.status))
    .help(t("action.open-job", job.name))
    .overlay(alignment: .trailing) {
      if showsHandoffSlot {
        HandoffItemControl(
          model: model,
          candidate: candidate,
          worktreeID: worktree.id,
          itemName: job.name,
          theme: theme,
        )
        .padding(.trailing, UIMetrics.servicePageSideInset)
      }
    }
  }
}
