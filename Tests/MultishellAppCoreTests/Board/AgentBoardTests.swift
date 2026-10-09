import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardTests {
  private let drawnAt = Date(timeIntervalSince1970: 1_000_000)

  private func card(
    _ name: String,
    isAgent: Bool = true,
    state: SessionState? = nil,
    secondsAgo: Double? = nil,
    title: String = "claude"
  ) -> AgentBoardCard {
    .sample(
      occupant: isAgent ? .agent(id: "claude", name: name) : .shell(name), title: title,
      state: state, since: secondsAgo.map { drawnAt.addingTimeInterval(-$0) })
  }

  @Test func everyOpenPaneHasExactlyOneCard() {
    let cards = [
      card("Claude Code", state: .attention),
      card("Codex", state: .running),
      card("Gemini CLI", state: .done),
      card("Copilot CLI"),
    ]
    let board = AgentBoard(cards: cards, showsAllTerminals: false)
    #expect(board.cardCount == cards.count)
    #expect(Set(board.columns.flatMap { $0.cards.map(\.id) }) == Set(cards.map(\.id)))
  }

  @Test func aPaneWithNothingToReportRestsInIdle() {
    let board = AgentBoard(cards: [card("Claude Code")], showsAllTerminals: false)
    #expect(board.count(of: .idle) == 1)
    #expect(board.column(.idle).cards[0].state == nil, "idle is the absence of a state")
    #expect(board.column(.idle).cards[0].lane == .idle)
    #expect(board.count(of: .waiting) == 0)
  }

  @Test func theFilterDecidesMembershipAndNeverTheColumn() {
    let cards = [
      card("Claude Code", state: .attention),
      card("zsh", isAgent: false, state: .running, title: "make release"),
      card("zsh", isAgent: false, state: .failed, title: "swift test"),
    ]

    let agentsOnly = AgentBoard(cards: cards, showsAllTerminals: false)
    #expect(agentsOnly.cardCount == 1)
    #expect(agentsOnly.count(of: .working) == 0)

    let everything = AgentBoard(cards: cards, showsAllTerminals: true)
    #expect(everything.cardCount == 3)
    #expect(everything.count(of: .working) == 1, "a shell lands where its state says")
    #expect(everything.count(of: .waiting) == 2, "its failure waits with the agent")
  }

  @Test func mostRecentlyEnteredThatStateComesFirst() {
    let cards = [
      card("Claude Code", state: .running, secondsAgo: 720, title: "oldest"),
      card("Codex", state: .running, secondsAgo: 41, title: "newest"),
      card("Copilot CLI", state: .running, secondsAgo: 120, title: "middle"),
    ]
    let working = AgentBoard(cards: cards, showsAllTerminals: false).column(.working).cards
    #expect(working.map(\.title) == ["newest", "middle", "oldest"])
  }

  @Test func aPaneThatHasNeverReportedSortsLastAndThenByTitle() {
    let cards = [
      card("Codex", title: "b"),
      card("Claude Code", state: nil, secondsAgo: 60, title: "reported"),
      card("Gemini CLI", title: "a"),
    ]
    let idle = AgentBoard(cards: cards, showsAllTerminals: false).column(.idle).cards
    #expect(idle.map(\.title) == ["reported", "a", "b"])
  }

  @Test func everyLaneHasAColumnEvenWithNothingInIt() {
    let board = AgentBoard(cards: [], showsAllTerminals: true)
    #expect(board.columns.map(\.lane) == AgentBoardLane.allCases)
    #expect(board.isEmpty)
    #expect(board.columns.allSatisfy { $0.cards.isEmpty })
  }
}
