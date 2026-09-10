/// Every open pane, in the column its state puts it in.
///
/// A roster, not a queue: a pane has exactly one card for as long as it is
/// open, and the card moves between columns as the pane's state moves. State
/// picks the column; it never decides whether a card exists.
public struct AgentBoard: Equatable, Sendable {
  public let columns: [AgentBoardColumn]

  /// `showsShells` is the board's one filter, and it decides membership
  /// alone: a shell it lets in lands in the column its state says, exactly
  /// as an agent does.
  public init(cards: [AgentBoardCard], showsShells: Bool) {
    let shown = (showsShells ? cards : cards.filter { $0.occupant.isAgent })
      .sorted(by: AgentBoardOrder.precedes)
    columns = AgentBoardLane.allCases.map { lane in
      AgentBoardColumn(lane: lane, cards: shown.filter { $0.lane == lane })
    }
  }

  public func column(_ lane: AgentBoardLane) -> AgentBoardColumn {
    columns.first { $0.lane == lane } ?? AgentBoardColumn(lane: lane, cards: [])
  }

  public func count(of lane: AgentBoardLane) -> Int {
    column(lane).count
  }

  public var cardCount: Int {
    columns.reduce(0) { $0 + $1.count }
  }

  public var isEmpty: Bool { cardCount == 0 }
}
