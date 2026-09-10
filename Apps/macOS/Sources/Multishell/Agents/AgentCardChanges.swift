import MultishellCore
import SwiftUI

/// The worktree's git badge on a card, drawn the way the sidebar row draws
/// it: the theme's yellow dot with the count, then the unpushed and unpulled
/// arrows.
struct AgentCardChanges: View {
  let status: WorktreeStatus
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 3) {
      if status.isDirty {
        Circle()
          .fill(theme.ansiRGB[3].color)
          .frame(width: 5, height: 5)
        Text("\(status.changedFiles)")
      }
      if status.ahead > 0 { Text("↑\(status.ahead)") }
      if status.behind > 0 { Text("↓\(status.behind)") }
    }
    .font(.system(size: metrics.badge, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(theme.textTertiary)
    .help(status.summary)
  }
}
