import MultishellAppCore
import MultishellCore
import SwiftUI

/// The Agents board: every open pane as a card. It decides nothing;
/// `AgentBoard` and `AgentBoardLayout` do, and this draws the answer.
struct AgentBoardView: View {
  let model: AppModel
  let theme: Theme

  /// One clock for every card's corner. Ten seconds, the shortest step a
  /// card's text takes past its first minute.
  private static let tick: TimeInterval = 10

  /// The clock the cards read, held rather than taken from a `TimelineView`,
  /// which stood still under a body re-evaluated several times a second.
  @State private var now = Date()

  var body: some View {
    let metrics = model.metrics
    let board = model.agentBoard
    VStack(spacing: 0) {
      AgentBoardHeader(model: model, board: board, theme: theme, metrics: metrics)
      // Always the columns, empty or not: labelled columns say what the
      // board is for, where a page says only that it is not working.
      scrollingColumns(board, metrics: metrics)
      if board.isEmpty {
        AgentBoardHint(theme: theme, metrics: metrics)
      }
    }
    .background(theme.backgroundColor)
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.tick))
        guard !Task.isCancelled else { return }
        now = Date()
      }
    }
  }

  private func scrollingColumns(_ board: AgentBoard, metrics: UIMetrics) -> some View {
    GeometryReader { proxy in
      let layout = layout(
        forWidth: proxy.size.width, count: board.columns.count, metrics: metrics)
      ScrollView(.horizontal, showsIndicators: layout.scrolls) {
        HStack(alignment: .top, spacing: metrics.boardGap) {
          ForEach(board.columns) { column in
            AgentBoardColumnView(
              model: model,
              column: column,
              width: layout.columnWidth,
              now: now,
              theme: theme,
              metrics: metrics)
          }
        }
        .padding(metrics.boardPadding)
        .frame(minWidth: layout.scrolls ? nil : proxy.size.width, alignment: .leading)
        .frame(height: proxy.size.height, alignment: .top)
      }
      .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
  }

  private func layout(forWidth width: Double, count: Int, metrics: UIMetrics) -> AgentBoardLayout {
    AgentBoardLayout(
      available: AgentBoardLayout.available(
        width: width, count: count, gap: metrics.boardGap, padding: metrics.boardPadding),
      count: count,
      minimum: metrics.boardColumnMinWidth)
  }
}
