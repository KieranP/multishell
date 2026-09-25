/// Every open pane, in the column its state puts it in. A roster, not a
/// queue; see Docs/design/agents.md.
public struct AgentBoard: Equatable, Sendable {
  public let columns: [AgentBoardColumn]

  /// `showsAllTerminals` is the board's one filter and decides membership
  /// alone: a shell it lets in lands where its state says, as an agent does.
  public init(cards: [AgentBoardCard], showsAllTerminals: Bool) {
    let shown = (showsAllTerminals ? cards : cards.filter { $0.occupant.isAgent })
      .sorted(by: AgentBoardOrder.precedes)
    var byLane: [AgentBoardLane: [AgentBoardCard]] = [:]
    for card in shown { byLane[card.lane, default: []].append(card) }
    columns = AgentBoardLane.allCases.map { AgentBoardColumn(lane: $0, cards: byLane[$0] ?? []) }
  }

  public func column(_ lane: AgentBoardLane) -> AgentBoardColumn {
    columns.first { $0.lane == lane } ?? AgentBoardColumn(lane: lane, cards: [])
  }

  public func count(of lane: AgentBoardLane) -> Int {
    column(lane).count
  }

  var cardCount: Int {
    columns.reduce(0) { $0 + $1.count }
  }

  public var isEmpty: Bool { cardCount == 0 }
}
