import Testing

@testable import MultishellCore

@Suite
struct KeyCombinationSpellingTests {
  @Test func aCombinationIsSpelledWithItsModifiersInMenuOrder() {
    #expect(KeyCombination(.character("k"), [.command, .shift]).spelled == "shift+cmd+k")
    #expect(KeyCombination(.tab, [.shift, .control]).spelled == "ctrl+shift+tab")
    #expect(KeyCombination(.character("\\"), .command).spelled == "cmd+backslash")
    #expect(KeyCombination(.character("+"), .command).spelled == "cmd+plus")
    #expect(KeyCombination(.function(5), []).spelled == "f5")
  }
  @Test func everySpellingReadsBackAsTheSameCombination() {
    let keys: [ShortcutKey] =
      ShortcutKey.named.map(\.key) + ShortcutKey.functionNumbers.map(ShortcutKey.function)
      + Array("abz09`-=[]\\;',./+ößı").map(ShortcutKey.character)
    for key in keys {
      let combination = KeyCombination(key, [.command, .option, .shift, .control])
      #expect(KeyCombination(spelled: combination.spelled) == combination, "\(combination)")
    }
  }

  @Test func aSpellingTakesAnyCaseAnyOrderAndAKeysOwnCharacter() {
    #expect(
      KeyCombination(spelled: "CMD+Shift+K")
        == KeyCombination(.character("k"), [.command, .shift])
    )
    #expect(KeyCombination(spelled: "cmd+\\") == KeyCombination(.character("\\"), .command))
    #expect(KeyCombination(spelled: "cmd++") == KeyCombination(.character("+"), .command))
  }
  @Test func aNamedKeysGlyphSpelledAsItsKeyIsThatKeyNotACharacter() {
    #expect(KeyCombination(spelled: "cmd+←") == KeyCombination(.leftArrow, .command))
    #expect(KeyCombination(spelled: "cmd+⌫") == KeyCombination(.backspace, .command))
    #expect(KeyCombination(spelled: "cmd+⌘") == nil, "a modifier is no key")
    for glyph in ["⏎", "⌤", "⎋", "⇪"] {
      #expect(KeyCombination(spelled: "cmd+\(glyph)") == nil, "no key types \(glyph)")
    }
  }

  @Test func aSpellingWithAnUnknownWordOrARepeatedModifierIsNoCombination() {
    #expect(KeyCombination(spelled: "hyper+k") == nil)
    #expect(KeyCombination(spelled: "cmd+cmd+k") == nil)
    #expect(KeyCombination(spelled: "cmd+") == nil)
    #expect(KeyCombination(spelled: "cmd+f21") == nil)
    #expect(KeyCombination(spelled: "cmd+ab") == nil)
  }
}
