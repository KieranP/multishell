import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyModifiersTests {
  private func has(_ mods: ghostty_input_mods_e, _ mod: ghostty_input_mods_e) -> Bool {
    mods.rawValue & mod.rawValue != 0
  }

  @Test func eachModifierKeyMapsToLibghosttysOwn() {
    let pairs: [(NSEvent.ModifierFlags, ghostty_input_mods_e)] = [
      (.shift, GHOSTTY_MODS_SHIFT), (.control, GHOSTTY_MODS_CTRL), (.option, GHOSTTY_MODS_ALT),
      (.command, GHOSTTY_MODS_SUPER), (.capsLock, GHOSTTY_MODS_CAPS),
    ]
    for (flag, mod) in pairs {
      #expect(GhosttyModifiers.mods(flag) == mod, "\(flag)")
    }
  }

  @Test func theRightOptionKeyIsToldApartSoOptionAsAltCanNameASide() {
    let right = NSEvent.ModifierFlags(
      rawValue: NSEvent.ModifierFlags.option.rawValue | UInt(NX_DEVICERALTKEYMASK))
    #expect(has(GhosttyModifiers.mods(right), GHOSTTY_MODS_ALT_RIGHT))
    #expect(!has(GhosttyModifiers.mods(.option), GHOSTTY_MODS_ALT_RIGHT))
  }

  @Test func flagsComeBackFromLibghosttysModifiers() {
    let flags: NSEvent.ModifierFlags = [.shift, .option]
    #expect(GhosttyModifiers.flags(GhosttyModifiers.mods(flags)) == flags)
  }

  @Test func aRightHandKeyIsDownOnlyWhileItsOwnSideIsHeld() {
    let rightShiftKey: UInt16 = 0x3C
    #expect(
      !GhosttyModifiers.isOwnSideDown(keyCode: rightShiftKey, in: shift(NX_DEVICELSHIFTKEYMASK)))
    #expect(
      GhosttyModifiers.isOwnSideDown(keyCode: rightShiftKey, in: shift(NX_DEVICERSHIFTKEYMASK)))
  }

  @Test func aLeftHandKeyIsDownOnlyWhileItsOwnSideIsHeld() {
    let leftShiftKey: UInt16 = 0x38
    #expect(
      !GhosttyModifiers.isOwnSideDown(keyCode: leftShiftKey, in: shift(NX_DEVICERSHIFTKEYMASK)))
    #expect(
      GhosttyModifiers.isOwnSideDown(keyCode: leftShiftKey, in: shift(NX_DEVICELSHIFTKEYMASK)))
  }

  @Test func aModifierKeyWithNoSideReportedIsDown() {
    #expect(GhosttyModifiers.isOwnSideDown(keyCode: 0x38, in: .shift))
    #expect(GhosttyModifiers.isOwnSideDown(keyCode: 0x3C, in: .shift))
  }

  private func shift(_ deviceMask: Int32) -> NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.shift.rawValue | UInt(deviceMask))
  }

  @Test func onlyModifierKeysNameAModifier() {
    #expect(GhosttyModifiers.mod(forKeyCode: 0x3A) == GHOSTTY_MODS_ALT)
    #expect(GhosttyModifiers.mod(forKeyCode: 0x00) == nil)
  }
}
