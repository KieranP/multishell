import MultishellAppCore
import MultishellCore
import SwiftUI

/// One column: a header that stays put and its cards under it.
///
/// The cards scroll inside the column rather than the board scrolling as a
/// whole, so a column with twenty cards does not push the other three
/// headers off the top of the window.
struct AgentBoardColumnView: View {
  let model: AppModel
  let column: AgentBoardColumn
  let width: Double
  let now: Date
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(spacing: 8) {
      header
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 8) {
          ForEach(column.cards) { card in
            AgentCardView(
              model: model, card: card, now: now, theme: theme, metrics: metrics)
          }
        }
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    // No spacer under the cards: the scroll view and a spacer are both
    // fully flexible, so a VStack would split the column between them and
    // leave the cards half a column to live in.
    .padding(8)
    .frame(width: width)
    .background(theme.columnColor, in: RoundedRectangle(cornerRadius: 8))
  }

  private var header: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(theme.color(for: column.lane.headerState))
        .frame(width: 7, height: 7)
      Text(column.lane.title())
        .font(.system(size: metrics.badge, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .lineLimit(1)
      Spacer(minLength: 4)
      Text("\(column.count)")
        .font(.system(size: metrics.badge))
        .monospacedDigit()
        .foregroundStyle(theme.textTertiary)
    }
    .padding(.horizontal, 2)
    .padding(.bottom, 6)
    .overlay(alignment: .bottom) { theme.hairline.frame(height: 0.5) }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(t("board.lane-count", column.lane.title(), column.count))
  }
}
