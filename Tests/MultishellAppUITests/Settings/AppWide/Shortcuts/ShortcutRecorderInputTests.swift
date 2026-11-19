import AppKit
import Carbon.HIToolbox
import MultishellCore
import Testing

@testable import MultishellAppUI

/// The key comes from the layout in use, so these hold a US keyboard's keys.
@Suite(.enabled(if: KeyboardInputSource.currentID == "com.apple.keylayout.US"))
@MainActor
struct ShortcutRecorderInputTests {
  private func input(
    _ characters: String,
    _ keyCode: Int,
    _ flags: NSEvent.ModifierFlags = [],
  ) throws -> ShortcutRecorderInput {
    ShortcutRecorderInput(try keyDown(characters, keyCode: UInt16(keyCode), flags: flags))
  }

  @Test func aKeyIsRecordedWithTheModifiersHeld() throws {
    #expect(
      try input("w", kVK_ANSI_W, .command) == .keys(KeyCombination(.character("w"), .command))
    )
  }

  @Test func shiftedPunctuationIsTheUnshiftedKeyWithShift() throws {
    #expect(
      try input("{", kVK_ANSI_LeftBracket, [.command, .shift])
        == .keys(KeyCombination(.character("["), [.command, .shift]))
    )
  }

  @Test func keysThatTypeNoCharacterAreRecordedByName() throws {
    #expect(try input("\u{F708}", kVK_F5, .function) == .keys(KeyCombination(.function(5))))
    #expect(
      try input("\u{F702}", kVK_LeftArrow, [.command, .option, .numericPad, .function])
        == .keys(KeyCombination(.leftArrow, [.command, .option]))
    )
    #expect(try input("\t", kVK_Tab, .control) == .keys(KeyCombination(.tab, .control)))
  }

  @Test func escapeCancelsAndDeleteAloneClears() throws {
    #expect(try input("\u{1B}", kVK_Escape) == .cancel)
    #expect(try input("\u{7F}", kVK_Delete) == .clear)
    #expect(
      try input("\u{7F}", kVK_Delete, .command) == .keys(KeyCombination(.backspace, .command))
    )
  }
}
