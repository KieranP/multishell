import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// How panes are sorted into columns, on the plain value the board is drawn
/// from. No workspace, no host and no clock.
@Suite
struct AgentBoardTests {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func card(
    _ name: String,
    agent: Bool = true,
    state: SessionState? = nil,
    secondsAgo: Double? = nil,
    note: SessionNote? = nil,
    title: String = "claude"
  ) -> AgentBoardCard {
    AgentBoardCard(
      id: UUID(),
      tabID: UUID(),
      worktreeID: "/w",
      occupant: agent ? .agent(name) : .shell(name),
      title: title,
      projectName: "multishell",
      worktreeName: "main",
      state: state,
      since: secondsAgo.map { start.addingTimeInterval(-$0) },
      note: note,
      status: nil)
  }

  @Test func everyOpenPaneHasExactlyOneCard() {
    let cards = [
      card("Claude Code", state: .attention),
      card("Codex", state: .running),
      card("Gemini CLI", state: .done),
      card("Copilot CLI"),
    ]
    let board = AgentBoard(cards: cards, showsShells: false)
    #expect(board.cardCount == cards.count)
    #expect(Set(board.columns.flatMap { $0.cards.map(\.id) }) == Set(cards.map(\.id)))
  }

  @Test func aFailureWaitsWithTheRestRatherThanSittingInDone() {
    #expect(AgentBoardLane.of(.attention) == .waiting)
    #expect(AgentBoardLane.of(.error) == .waiting, "a failure wants the user")
    #expect(AgentBoardLane.of(.running) == .working)
    #expect(AgentBoardLane.of(.done) == .done)
    #expect(AgentBoardLane.of(nil) == .idle)
    #expect(AgentBoardLane.of(.idle) == .idle, "idle is the absence of a state")
  }

  @Test func aPaneWithNothingToReportRestsInIdle() {
    let board = AgentBoard(cards: [card("Claude Code")], showsShells: false)
    #expect(board.count(of: .idle) == 1)
    #expect(board.column(.idle).cards[0].state == nil, "idle is the absence of a state")
    #expect(board.column(.idle).cards[0].lane == .idle)
    #expect(board.count(of: .waiting) == 0)
  }

  @Test func theFilterDecidesMembershipAndNeverTheColumn() {
    let cards = [
      card("Claude Code", state: .attention),
      card("zsh", agent: false, state: .running, title: "make release"),
      card("zsh", agent: false, state: .error, title: "swift test"),
    ]

    let agentsOnly = AgentBoard(cards: cards, showsShells: false)
    #expect(agentsOnly.cardCount == 1)
    #expect(agentsOnly.count(of: .working) == 0)

    let everything = AgentBoard(cards: cards, showsShells: true)
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
    let working = AgentBoard(cards: cards, showsShells: false).column(.working).cards
    #expect(working.map(\.title) == ["newest", "middle", "oldest"])
  }

  @Test func aPaneThatHasNeverReportedSortsLastAndThenByTitle() {
    let cards = [
      card("Codex", title: "b"),
      card("Claude Code", state: nil, secondsAgo: 60, title: "reported"),
      card("Gemini CLI", title: "a"),
    ]
    let idle = AgentBoard(cards: cards, showsShells: false).column(.idle).cards
    #expect(idle.map(\.title) == ["reported", "a", "b"])
  }

  @Test func aCardShowsTheMessageOnlyWhileItStillDescribesThePane() {
    let asked = SessionNote(state: .attention, message: "Permission to run rm -rf .build")
    let waiting = (card("Claude Code", state: .attention, note: asked))
    #expect(waiting.message == "Permission to run rm -rf .build")

    // The engine saw the command finish, which no report corrected: the
    // question the pane was asking is not what it is doing now.
    let finished = (card("Claude Code", state: .done, note: asked))
    #expect(finished.message == nil)
  }

  @Test func aFinishedCommandSaysHowLongItTook() {
    let done = SessionNote(state: .done, duration: 194)
    #expect((card("zsh", state: .done, note: done)).message == "Done · 3m 14s")

    let failed = SessionNote(state: .error, duration: 72)
    #expect(
      (card("zsh", state: .error, note: failed)).message == "Failed · 1m 12s")

    let working = SessionNote(state: .running, duration: 5)
    #expect(
      (card("zsh", state: .running, note: working)).message == nil,
      "a command still running has taken no time yet")
  }

  @Test func aCardSaysHowLongItHasBeenInItsColumn() {
    #expect(card("Claude Code", state: .running, secondsAgo: 750).elapsed(at: start) == "12m")
    #expect(card("Codex").elapsed(at: start) == nil)
  }

  @Test func everyLaneHasAColumnEvenWithNothingInIt() {
    let board = AgentBoard(cards: [], showsShells: true)
    #expect(board.columns.map(\.lane) == AgentBoardLane.allCases)
    #expect(board.isEmpty)
    #expect(board.columns.allSatisfy { $0.cards.isEmpty })
  }

  @Test func theBoardSaysWhatItHoldsAndWhatItIsEmptyOf() {
    let busy = AgentBoard(
      cards: [card("Claude Code", state: .attention), card("Codex", state: .running)],
      showsShells: false)
    #expect(busy.summary == "2 terminals · 1 waiting on you")

    let quiet = AgentBoard(cards: [card("Codex", state: .running)], showsShells: false)
    #expect(quiet.summary == "1 terminal", "nothing wants the user, so nothing is said about it")

    #expect(AgentBoard(cards: [], showsShells: false).summary == "0 terminals")
  }

  /// The sidebar entry leaves Idle off: it is where most cards rest, so its
  /// number says nothing about whether the board is worth opening.
  @Test func theSidebarSummarisesEveryLaneButIdle() {
    #expect(AgentBoardLane.summarised == [.waiting, .working, .done])
  }

  /// The columns read left to right, most urgent first.
  @Test func theColumnsAreInTheOrderTheyAreDrawn() {
    #expect(AgentBoardLane.allCases == [.waiting, .working, .done, .idle])
    #expect(AgentBoardLane.waiting.headerState == .attention)
    #expect(AgentBoardLane.idle.headerState == .idle)
  }
}

@Suite
struct ElapsedTextTests {
  @Test func aGlanceIsSecondsThenMinutesThenHours() {
    #expect(ElapsedText.short(0) == "0s")
    #expect(ElapsedText.short(41) == "41s")
    #expect(ElapsedText.short(59.9) == "59s")
    #expect(ElapsedText.short(60) == "1m")
    #expect(ElapsedText.short(750) == "12m")
    #expect(ElapsedText.short(3900) == "1h 05m")
    #expect(ElapsedText.short(-1) == nil, "a clock that moved backwards says nothing")
    #expect(ElapsedText.short(.infinity) == nil)
  }

  @Test func aCommandsRuntimeKeepsItsSeconds() {
    #expect(ElapsedText.precise(0.42) == "0.4s")
    #expect(ElapsedText.precise(9.5) == "9.5s")
    #expect(ElapsedText.precise(45) == "45s")
    #expect(ElapsedText.precise(194) == "3m 14s")
    #expect(ElapsedText.precise(3900) == "1h 05m")
  }

  @Test func aTimeIsMeasuredFromWhenTheStateBegan() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    #expect(ElapsedText.short(since: now.addingTimeInterval(-120), now: now) == "2m")
    #expect(ElapsedText.short(since: nil, now: now) == nil)
  }
}
