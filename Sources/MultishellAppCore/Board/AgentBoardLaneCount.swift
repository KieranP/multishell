/// How many cards one board column holds, as the sidebar's Agents entry
/// carries it.
public struct AgentBoardLaneCount: Equatable, Sendable {
  public let lane: AgentBoardLane
  public let count: Int

  init(_ lane: AgentBoardLane, _ count: Int) {
    self.lane = lane
    self.count = count
  }
}
