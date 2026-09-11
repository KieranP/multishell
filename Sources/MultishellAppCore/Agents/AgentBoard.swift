/// Every open pane, in the column its state puts it in. A roster, not a
/// queue; see docs/design/agents.md.
public struct AgentBoard: Equatable, Sendable {
  public let columns: [AgentBoardColumn]

  /// `showsShells` is the board's one filter and decides membership alone: a
  /// shell it lets in lands where its state says, as an agent does.
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
