import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardLaneTests {
  @Test func aFailureWaitsWithTheRestRatherThanSittingInDone() {
    #expect(AgentBoardLane.of(.attention) == .waiting)
    #expect(AgentBoardLane.of(.failed) == .waiting, "a failure wants the user")
    #expect(AgentBoardLane.of(.running) == .working)
    #expect(AgentBoardLane.of(.done) == .done)
    #expect(AgentBoardLane.of(nil) == .idle)
    #expect(AgentBoardLane.of(.idle) == .idle, "idle is the absence of a state")
  }

  @Test func theColumnsAreInDrawingOrderEachHeadedByItsState() {
    #expect(AgentBoardLane.allCases == [.waiting, .working, .done, .idle])
    #expect(AgentBoardLane.waiting.headerState == .attention)
    #expect(AgentBoardLane.idle.headerState == .idle)
  }
}
