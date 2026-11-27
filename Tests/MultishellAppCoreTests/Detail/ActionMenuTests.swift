import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ActionMenuTests {
  private func menu(_ states: [ActionRunState], awaitingTrust: [String] = []) -> ActionMenu {
    let items = states.enumerated().map { ActionMenuItem(name: "\($0)", state: $1, keys: nil) }
    return ActionMenu(groups: items.isEmpty ? [] : [items], awaitingTrust: awaitingTrust)
  }

  @Test func reviewAndTrustIsOfferedOnlyWhileAFileAwaitsTrust() {
    #expect(menu([], awaitingTrust: ["Lint"]).offersReviewAndTrust)
    #expect(!menu([.idle]).offersReviewAndTrust)
  }

  @Test func theEditItemsAreSetApartOnlyFromRowsAboveThem() {
    #expect(menu([.idle]).separatesEditItems)
    #expect(menu([], awaitingTrust: ["Lint"]).separatesEditItems)
    #expect(!menu([]).separatesEditItems)
  }

  @Test func rowsAreMarkedOnlyWhileOneOfThemHasAState() {
    #expect(!menu([.idle, .idle]).marksRows)
    #expect(menu([.idle, .failed]).marksRows)
    #expect(menu([.running(since: Date()), .idle]).marksRows)
  }

  @Test func workingDotsTurnOnlyWhileOneRunsAndMotionIsNotReduced() {
    #expect(menu([.running(since: Date())]).turnsWorkingDots(reducingMotion: false))
    #expect(!menu([.running(since: Date())]).turnsWorkingDots(reducingMotion: true))
    #expect(!menu([.failed, .idle]).turnsWorkingDots(reducingMotion: false))
  }
}
