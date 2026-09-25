import MultishellCore
import SwiftUI

/// The worktree's git badge on a card, as the sidebar row draws it.
struct AgentCardChanges: View {
  let status: WorktreeStatus
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    ChangeCounts(status: status, theme: theme, size: metrics.badge, tint: theme.textTertiary)
  }
}
