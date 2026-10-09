import Foundation
import MultishellAppCore

/// The agent board's sizes: the columns it lays out and the cards in them.
extension UIMetrics {
  static let cardCornerRadius: Double = 6
  /// The narrowest a board column is drawn, below which a card's two split
  /// rows run into themselves. See `AgentBoardLayout`.
  var boardColumnMinWidth: Double { (bodySize * 16).rounded() }
  /// Between two board columns. It and `boardPadding` are taken off before
  /// a column width is asked for, so nothing measures itself.
  var boardGap: Double { (bodySize * 0.8).rounded() }
  var boardPadding: Double { (bodySize * 0.9).rounded() }

  func boardLayout(forWidth width: Double, count: Int) -> AgentBoardLayout {
    AgentBoardLayout(
      available: AgentBoardLayout.available(
        width: width, count: count, gap: boardGap, padding: boardPadding),
      count: count, minimum: boardColumnMinWidth)
  }
}
