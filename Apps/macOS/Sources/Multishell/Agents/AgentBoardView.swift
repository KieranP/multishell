import MultishellAppCore
import MultishellCore
import SwiftUI

/// The Agents board: every open pane as a card, in the column its state puts
/// it in.
///
/// It decides nothing. `AgentBoard` arranges the cards, `AgentBoardLayout`
/// says how wide a column is and whether the board scrolls, and this draws
/// the answer.
struct AgentBoardView: View {
  let model: AppModel
  let theme: Theme

  /// One clock for every card's corner. Ten seconds: the shortest step a
  /// card's text can take past its first minute, so a faster tick would
  /// redraw the board for nothing.
  private static let tick: TimeInterval = 10

  /// The clock the cards read, held rather than taken from a `TimelineView`,
  /// which stood still. The board's body reads the titles, states and
  /// statuses of panes that keep running behind it, so it is re-evaluated
  /// several times a second, and the likely cause is that each of those
  /// rebuilt the schedule from a later `.now`; that part is reasoning, not
  /// something anyone watched. What was watched, through a temporary log in
  /// this task, is that a held clock ticks on time and starts once, so no
  /// identity churn restarts it. Writing this invalidates the view whatever
  /// the body does, which is why it does not rest on the diagnosis.
  @State private var now = Date()

  var body: some View {
    let metrics = model.metrics
    let board = model.agentBoard
    VStack(spacing: 0) {
      AgentBoardHeader(model: model, board: board, theme: theme, metrics: metrics)
      // Always the columns, empty or not: four labelled columns say what the
      // board is for, where a page in their place says only that it is not
      // working.
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
