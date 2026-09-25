import MultishellCore
import SwiftUI

/// Which pane of a split a row or a card is, drawn the same in the sidebar and
/// on the board: a renamed tab gives both its panes one title.
struct PanePositionBadge: View {
  let index: Int
  let metrics: UIMetrics
  let theme: Theme

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: AgentMarkView.splitSymbol)
        .font(.system(size: metrics.badge - 2))
      Text("\(index)")
        .font(.system(size: metrics.badge - 1, weight: .medium, design: .monospaced))
    }
    .foregroundStyle(theme.textTertiary)
  }
}
