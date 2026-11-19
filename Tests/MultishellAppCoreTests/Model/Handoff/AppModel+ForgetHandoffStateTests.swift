import Foundation
import Observation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelForgetHandoffStateTests {
  @Test func forgettingAWorktreeWithNoSendStateRedrawsNothing() {
    let harness = Harness()
    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.handoff.recipientPicks
      _ = harness.model.handoff.choices
      _ = harness.model.handoff.receipts
      _ = harness.model.handoff.misses
      _ = harness.model.focusedSessionHistory
    } onChange: {
      wrote.raise()
    }

    harness.model.forgetHandoffState(of: [harness.feature.id])

    #expect(!wrote.raised)
  }

  @Test func aRemovedWorktreeLosesItsPickChoicesReceiptsMissesAndFocusHistory() {
    let harness = Harness()
    let id = harness.feature.id
    harness.model.pickHandoffRecipient(UUID(), in: id)
    harness.model.focusedSessionHistory[id] = [UUID()]
    harness.model.handoff.choices[id] = HandoffChoices()
    harness.model.handoff.receipts[id] = [.ciRuns: "1 job sent to Claude Code"]
    harness.model.noteHandoffMiss("Nothing was sent.", on: .pullRequest, in: id)

    harness.model.forgetHandoffState(of: [id])

    #expect(harness.model.handoff.recipientPicks[id] == nil)
    #expect(harness.model.focusedSessionHistory[id] == nil)
    #expect(harness.model.handoff.choices[id] == nil)
    #expect(harness.model.handoff.receipts[id] == nil)
    #expect(harness.model.handoff.misses[id] == nil)
  }
}
