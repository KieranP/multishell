import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

/// The texts below are a US layout's; another layout types its own, as a
/// person's keyboard would.
@Suite(.enabled(if: KeyboardInputSource.currentID == "com.apple.keylayout.US"))
@MainActor
struct GhosttyKeyInputControlKeyTests {
  private func input(_ spelled: String) throws -> GhosttyKeyInput {
    let key = try #require(ControlKey(parsing: spelled))
    return try #require(GhosttyKeyInput(key, GHOSTTY_ACTION_PRESS))
  }

  @Test func aKeyTypesWhatThatKeyTypesOnTheKeyboard() throws {
    #expect(try input("a").text == "a")
    #expect(try input("space").text == " ")
    #expect(try input("shift-a").text == "A")
    #expect(try input("shift-1").text == "!")
    #expect(try input("shift-;").text == ":")
  }

  @Test func shiftIsTheModifierThatMadeTheTextAsOnARealKey() throws {
    #expect(try input("shift-a").consumedMods == GHOSTTY_MODS_SHIFT)
    #expect(try input("ctrl-c").consumedMods == GHOSTTY_MODS_NONE)
  }

  @Test func aNamedKeyTypesNoTextLibghosttyEncodesIt() throws {
    #expect(try input("up").text == nil)
    #expect(try input("f5").text == nil)
  }

  @Test func aControlChordCarriesItsLetterAsAKeyboardsDoes() throws {
    #expect(try input("ctrl-c").text == "c")
  }

  @Test func everyKeyTheCommandLineAcceptsHasAKeyCodeHere() {
    for name in ControlKey.names + ControlKey.characters.map(String.init) {
      let key = ControlKey(parsing: name)
      #expect(key.flatMap { GhosttyKeyInput($0, GHOSTTY_ACTION_PRESS) } != nil, "\(name)")
    }
  }

  @Test func optionTypesTheLayoutsCharacterUnlessLibghosttyTakesItAsAlt() throws {
    let key = try #require(ControlKey(parsing: "alt-x"))

    let asOption = try #require(GhosttyKeyInput(key, GHOSTTY_ACTION_PRESS))
    let asAlt = try #require(GhosttyKeyInput(key, GHOSTTY_ACTION_PRESS, translationFlags: []))

    #expect(asOption.text == "≈")
    #expect(asAlt.text == "x")
    #expect(asAlt.mods == GHOSTTY_MODS_ALT)
  }
}
