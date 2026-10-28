import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// An earlier run of the branch: its outcome, commit and when, opening onto
/// its workflows and jobs, read as it opens.
struct CIHistoryRow: View {
  let model: AppModel
  let worktree: Worktree
  let run: CIRun
  /// The page's clock, which a run's age is told against.
  let now: Date
  let theme: Theme

  @State private var isExpanded = false

  var body: some View {
    let metrics = model.metrics
    VStack(alignment: .leading, spacing: 0) {
      Button {
        isExpanded.toggle()
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          CIRunGlyph(
            status: run.status,
            theme: theme,
            palette: theme.filesPanel,
            size: metrics.servicePageRowGlyphSize,
          )
          VStack(alignment: .leading, spacing: 2) {
            Text(run.headline)
              .font(metrics.font(size: metrics.caption))
              .foregroundStyle(theme.filesPanel.text)
              .lineLimit(1)
            Text(run.startText(localTip: model.services(of: worktree).localTip, now: now))
              .font(metrics.font(size: metrics.small))
              .foregroundStyle(theme.filesPanel.textTertiary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          DisclosureChevron(isExpanded: isExpanded, metrics: metrics)
            .foregroundStyle(theme.filesPanel.textTertiary)
        }
        .padding(.horizontal, UIMetrics.servicePageSideInset)
        .padding(.vertical, 6)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityValue(AccessibilityText.ciStatus(run.status, isExpanded: isExpanded))
      if isExpanded {
        CIWorkflowList(model: model, worktree: worktree, run: run, theme: theme)
      }
    }
  }
}
