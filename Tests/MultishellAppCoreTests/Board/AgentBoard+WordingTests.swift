import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardWordingTests {
  @Test func theBoardSaysWhatItHoldsAndWhatItIsEmptyOf() {
    let claude = AgentBoardCard.sample(
      occupant: .agent(id: "claude", name: "Claude Code"),
      state: .attention,
    )
    let codex = AgentBoardCard.sample(
      occupant: .agent(id: "codex", name: "Codex"),
      state: .running,
    )

    let busy = AgentBoard(cards: [claude, codex], showsAllTerminals: false)
    #expect(busy.summary == "2 terminals · 1 waiting on you")

    let quiet = AgentBoard(cards: [codex], showsAllTerminals: false)
    #expect(quiet.summary == "1 terminal", "nothing wants the user, so nothing is said about it")

    #expect(AgentBoard(cards: [], showsAllTerminals: false).summary == "0 terminals")
  }
}
