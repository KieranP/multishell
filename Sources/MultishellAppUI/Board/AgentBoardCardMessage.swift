import MultishellCore
import SwiftUI

/// The last thing a pane said about itself, set off from the card's own
/// lines: it is the occupant's words, not the app's.
struct AgentBoardCardMessage: View {
  let text: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(text)
      .font(metrics.font(size: metrics.badge))
      .foregroundStyle(theme.agentsCard.textSecondary)
      .lineLimit(3)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 6)
      .padding(.vertical, 4)
      .padding(.trailing, 4)
      .background(theme.agentsCard.fill, in: RoundedRectangle(cornerRadius: 4))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(theme.agentsCard.border)
          .frame(width: 2)
      }
  }
}
