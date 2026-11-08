import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardCardTests {
  private let claude = AgentBoardCard.Occupant.agent(id: "claude", name: "Claude Code")

  @Test func aCardWearsNoStateDotWhereItsColumnAlreadySaysTheState() {
    for state in [SessionState.attention, .running, .done, .idle] {
      #expect(
        AgentBoardCard.sample(occupant: claude, state: state).dotState == nil,
        "\(state)",
      )
    }
    #expect(AgentBoardCard.sample(occupant: claude).dotState == nil)
  }

  @Test func aFailedCardKeepsItsDotSinceItWaitsInTheWaitingColumn() {
    #expect(AgentBoardCard.sample(occupant: claude, state: .failed).dotState == .failed)
  }
}
