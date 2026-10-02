import MultishellAppCore
import MultishellCore
import SwiftUI

/// Which pane of a split a row or a card is, drawn the same in the sidebar and
/// on the board: a renamed tab gives both its panes one title.
struct PanePositionBadge: View {
  let number: Int
  let metrics: UIMetrics
  let theme: Theme

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: PaneSymbol.split)
        .font(.system(size: metrics.badge - 2))
      Text("\(number)")
        .font(.system(size: metrics.small, weight: .medium, design: .monospaced))
    }
    .foregroundStyle(theme.textTertiary)
  }
}
