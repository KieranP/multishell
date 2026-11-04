/// One lane's cards, in the order the board put them in.
public struct AgentBoardColumn: Identifiable, Equatable, Sendable {
  public let lane: AgentBoardLane
  public let cards: [AgentBoardCard]

  public var id: AgentBoardLane { lane }
  public var count: Int { cards.count }
  /// An empty column's header dot only names its lane, so it holds still.
  public var animatesHeader: Bool { !cards.isEmpty }
}
