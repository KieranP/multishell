import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardColumnTests {
  @Test func anEmptyColumnsHeaderHoldsStill() {
    #expect(!AgentBoardColumn(lane: .waiting, cards: []).animatesHeader)
  }

  @Test func aColumnWithACardAnimatesItsHeader() {
    let card = AgentBoardCard.sample(
      occupant: .agent(id: "claude", name: "Claude Code"),
      state: .attention,
    )
    #expect(AgentBoardColumn(lane: .waiting, cards: [card]).animatesHeader)
  }
}
