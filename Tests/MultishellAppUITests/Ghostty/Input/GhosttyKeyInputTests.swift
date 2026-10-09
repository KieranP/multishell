import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyKeyInputTests {
  @Test func aShiftedLetterCarriesItsTextAndTheKeysUnshiftedCharacter() throws {
    let event = try keyDown("A", keyCode: 0x00, flags: .shift)
    let input = GhosttyKeyInput(event, GHOSTTY_ACTION_PRESS, text: "A")
    #expect(input.text == "A")
    #expect(input.keyCode == 0x00)
    let unshifted = try #require(event.characters(byApplyingModifiers: [])?.unicodeScalars.first)
    #expect(input.unshiftedCodepoint == unshifted.value)
    #expect(input.unshiftedCodepoint != ("A" as Unicode.Scalar).value, "not the typed letter")
  }

  @Test func controlAndCommandAreNeverCountedAsMakingTheText() throws {
    let event = try keyDown("c", keyCode: 0x08, flags: [.control, .command, .shift])
    let input = GhosttyKeyInput(event, GHOSTTY_ACTION_PRESS)
    #expect(input.consumedMods == GHOSTTY_MODS_SHIFT)
    #expect(input.mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0)
  }

  @Test func optionAsAltLeavesOptionOutOfWhatMadeTheText() throws {
    let event = try keyDown("f", keyCode: 0x03, flags: .option)
    let input = GhosttyKeyInput(event, GHOSTTY_ACTION_PRESS, translationFlags: [])
    #expect(input.mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0, "still held")
    #expect(input.consumedMods == GHOSTTY_MODS_NONE, "but not what made the text")
  }

  @Test func aControlCharacterOrDeleteGoesAsNoTextForLibghosttyToEncode() throws {
    let control = GhosttyKeyInput(
      try keyDown("\u{3}", keyCode: 0x08),
      GHOSTTY_ACTION_PRESS,
      text: "\u{3}",
    )
    #expect(control.text == nil)
    let delete = GhosttyKeyInput(
      try keyDown("\u{7F}", keyCode: 0x33),
      GHOSTTY_ACTION_PRESS,
      text: "\u{7F}",
    )
    #expect(delete.text == nil)
  }

  @Test func committedTextCarriesNoKeyOrModifiers() {
    let input = GhosttyKeyInput(committing: "日本")
    #expect(input.text == "日本")
    #expect(input.keyCode == 0)
    #expect(input.mods == GHOSTTY_MODS_NONE)
  }

  @Test func theTextReachesLibghosttyAsACString() throws {
    let input = GhosttyKeyInput(
      try keyDown("x", keyCode: 0x07),
      GHOSTTY_ACTION_RELEASE,
      text: "x",
    )
    let sent = input.withCValue { key in (key.action, key.text.map { String(cString: $0) }) }
    #expect(sent.0 == GHOSTTY_ACTION_RELEASE)
    #expect(sent.1 == "x")
  }
}
