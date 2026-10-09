import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardLaneSidebarTests {
  /// The sidebar entry leaves Idle off: it is where most cards rest, so its
  /// number says nothing about whether the board is worth opening.
  @Test func theSidebarSummarisesEveryLaneButIdle() {
    #expect(AgentBoardLane.sidebarLanes == [.waiting, .working, .done])
  }
}
