import Testing

@testable import MultishellCore

@Suite
struct KeyCombinationGlyphsTests {
  @Test func glyphsAreDrawnAsAMenuDrawsThem() {
    #expect(KeyCombination(.character("k"), [.shift, .command]).glyphs == "⇧⌘K")
    #expect(KeyCombination(.tab, [.control, .shift]).glyphs == "⌃⇧⇥")
    #expect(KeyCombination(.rightArrow, [.command, .option]).glyphs == "⌥⌘→")
  }
  @Test func everyCombinationsGlyphsReadBackAsTheSameCombination() {
    let keys: [ShortcutKey] =
      ShortcutKey.named.map(\.key) + ShortcutKey.functionNumbers.map(ShortcutKey.function)
      + Array("abz09`-=[]\\;',./+ößı").map(ShortcutKey.character)
    for key in keys {
      let combination = KeyCombination(key, [.command, .option, .shift, .control])
      #expect(KeyCombination(glyphs: combination.glyphs) == combination, "\(combination)")
    }
  }

  @Test func aCapitalInGlyphsIsTheLetterWithoutShiftUnlessShiftIsDrawn() {
    #expect(KeyCombination(glyphs: "⌘K") == KeyCombination(.character("k"), .command))
    #expect(KeyCombination(glyphs: "⌘⌘K") == nil)
  }
}
