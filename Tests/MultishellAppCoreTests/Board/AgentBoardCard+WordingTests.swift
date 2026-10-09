import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentBoardCardWordingTests {
  private let drawnAt = Date(timeIntervalSince1970: 1_000_000)
  private let claude = AgentBoardCard.Occupant.agent(id: "claude", name: "Claude Code")

  @Test func aCardShowsTheMessageOnlyWhileItStillDescribesThePane() {
    let asked = SessionNote(state: .attention, message: "Permission to run rm -rf .build")
    let waiting = AgentBoardCard.sample(occupant: claude, state: .attention, note: asked)
    #expect(waiting.message == "Permission to run rm -rf .build")

    let finished = AgentBoardCard.sample(occupant: claude, state: .done, note: asked)
    #expect(finished.message == nil)
  }

  @Test func aFinishedCommandSaysHowLongItTook() {
    let done = SessionNote(state: .done, duration: 194)
    #expect(
      AgentBoardCard.sample(occupant: .shell("zsh"), state: .done, note: done).message
        == "Done · 3m 14s"
    )

    let failed = SessionNote(state: .failed, duration: 72)
    #expect(
      AgentBoardCard.sample(occupant: .shell("zsh"), state: .failed, note: failed).message
        == "Failed · 1m 12s"
    )

    let working = SessionNote(state: .running, duration: 5)
    #expect(
      AgentBoardCard.sample(occupant: .shell("zsh"), state: .running, note: working).message
        == nil,
      "a command still running has taken no time yet",
    )
  }

  @Test func aCardSaysHowLongItHasBeenInItsColumn() {
    let since = drawnAt.addingTimeInterval(-750)
    #expect(
      AgentBoardCard.sample(occupant: claude, state: .running, since: since).elapsed(at: drawnAt)
        == "12m"
    )
    #expect(AgentBoardCard.sample(occupant: claude).elapsed(at: drawnAt) == nil)
  }

  /// The board's clock lags by up to a tick, so a pane that has just entered
  /// its column is younger than the `now` the cards are drawn against.
  @Test func aCardThatEnteredItsColumnSinceTheLastTickReadsZeroRatherThanNothing() {
    let since = drawnAt.addingTimeInterval(8)
    #expect(
      AgentBoardCard.sample(occupant: claude, state: .running, since: since).elapsed(at: drawnAt)
        == "0s"
    )
  }
}
