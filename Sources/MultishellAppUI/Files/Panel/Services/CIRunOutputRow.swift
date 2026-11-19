import MultishellAppCore
import MultishellCore
import SwiftUI

/// "Run output" over the report's text that names no listed job, with its
/// checkbox: it can be the only failure, a config error before any job ran.
struct CIRunOutputRow: View {
  let model: AppModel
  let worktree: Worktree
  let output: CIHandoffItem
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 7) {
      Text(output.heading)
        .font(metrics.font(size: metrics.secondary, weight: .semibold))
        .foregroundStyle(theme.filesPanel.text)
        .lineLimit(1)
      Spacer(minLength: 0)
      HandoffItemControl(
        model: model,
        candidate: output.candidate,
        worktreeID: worktree.id,
        itemName: output.heading,
        theme: theme,
      )
    }
    .padding(.horizontal, UIMetrics.servicePageSideInset)
    .frame(height: metrics.paneRowHeight)
  }
}
