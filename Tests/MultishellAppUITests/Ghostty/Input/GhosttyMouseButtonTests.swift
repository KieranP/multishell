import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyMouseButtonTests {
  @Test func theThreeUsualButtonsKeepTheirNames() {
    #expect(GhosttyMouseButton.button(forNumber: 0) == GHOSTTY_MOUSE_LEFT)
    #expect(GhosttyMouseButton.button(forNumber: 1) == GHOSTTY_MOUSE_RIGHT)
    #expect(GhosttyMouseButton.button(forNumber: 2) == GHOSTTY_MOUSE_MIDDLE)
  }

  @Test func backAndForwardAreTheButtonsXtermNumbersEightAndNine() {
    #expect(GhosttyMouseButton.button(forNumber: 3) == GHOSTTY_MOUSE_EIGHT)
    #expect(GhosttyMouseButton.button(forNumber: 4) == GHOSTTY_MOUSE_NINE)
  }

  @Test func aButtonPastTheEleventhIsUnknownRatherThanMiddle() {
    #expect(GhosttyMouseButton.button(forNumber: 11) == GHOSTTY_MOUSE_UNKNOWN)
  }
}
