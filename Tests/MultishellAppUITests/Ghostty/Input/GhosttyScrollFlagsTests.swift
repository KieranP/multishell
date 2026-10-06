import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyScrollFlagsTests {
  @Test func aMouseWheelIsNeitherPreciseNorMoving() {
    #expect(GhosttyScrollFlags(isPrecise: false, momentum: []).rawValue == 0)
  }

  @Test func aTrackpadSetsTheLowBitAndItsMomentumTheThreeAbove() {
    let flags = GhosttyScrollFlags(isPrecise: true, momentum: .changed)
    #expect(flags.rawValue & 1 == 1)
    #expect(
      flags.rawValue >> 1 == ghostty_input_scroll_mods_t(GHOSTTY_MOUSE_MOMENTUM_CHANGED.rawValue))
  }

  @Test func eachMomentumPhaseIsLibghosttysOwn() {
    let phases: [(NSEvent.Phase, ghostty_input_mouse_momentum_e)] = [
      (.began, GHOSTTY_MOUSE_MOMENTUM_BEGAN), (.stationary, GHOSTTY_MOUSE_MOMENTUM_STATIONARY),
      (.changed, GHOSTTY_MOUSE_MOMENTUM_CHANGED), (.ended, GHOSTTY_MOUSE_MOMENTUM_ENDED),
      (.cancelled, GHOSTTY_MOUSE_MOMENTUM_CANCELLED), (.mayBegin, GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN),
    ]
    for (phase, momentum) in phases {
      let flags = GhosttyScrollFlags(isPrecise: true, momentum: phase)
      #expect(flags.rawValue >> 1 == ghostty_input_scroll_mods_t(momentum.rawValue))
    }
  }
}
