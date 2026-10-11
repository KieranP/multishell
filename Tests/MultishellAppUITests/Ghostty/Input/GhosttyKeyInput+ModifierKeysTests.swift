import AppKit
import Carbon.HIToolbox
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct GhosttyKeyInputModifierKeysTests {
  @Test func aChordsModifiersGoDownInTurnEachHeldWithThoseBeforeIt() {
    let presses = GhosttyKeyInput.modifierPresses(for: [.control, .shift])

    #expect(presses.map(\.keyCode) == [UInt32(kVK_Shift), UInt32(kVK_Control)])
    #expect(presses.map(\.action) == [GHOSTTY_ACTION_PRESS, GHOSTTY_ACTION_PRESS])
    #expect(
      presses.map(\.mods.rawValue) == [
        GHOSTTY_MODS_SHIFT.rawValue, GHOSTTY_MODS_SHIFT.rawValue | GHOSTTY_MODS_CTRL.rawValue,
      ]
    )
    #expect(presses.allSatisfy { $0.text == nil })
  }

  @Test func aChordsModifiersComeUpInReverseLeavingNoneHeld() {
    let releases = GhosttyKeyInput.modifierReleases(for: [.command, .shift])

    #expect(releases.map(\.keyCode) == [UInt32(kVK_Command), UInt32(kVK_Shift)])
    #expect(releases.map(\.action) == [GHOSTTY_ACTION_RELEASE, GHOSTTY_ACTION_RELEASE])
    #expect(releases.last?.mods == GHOSTTY_MODS_NONE)
  }

  @Test func aKeyWithNoModifiersSendsNoneOfThem() {
    #expect(GhosttyKeyInput.modifierPresses(for: []).isEmpty)
    #expect(GhosttyKeyInput.modifierReleases(for: []).isEmpty)
  }
}
