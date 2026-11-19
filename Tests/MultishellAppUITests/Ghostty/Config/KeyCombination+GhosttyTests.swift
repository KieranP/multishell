import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct KeyCombinationGhosttyTests {
  @Test func aCombinationIsSpelledAsGhosttysDocsSpellIt() {
    #expect(
      ShortcutCommand.newTab.defaultCombination.ghosttyTriggers == ["super+t", "super+key_t"]
    )
    #expect(
      ShortcutCommand.newAgentTab.defaultCombination.ghosttyTriggers
        == ["super+alt+t", "super+alt+key_t"]
    )
    #expect(ShortcutCommand.nextTab.defaultCombination.ghosttyTriggers == ["ctrl+tab"])
    #expect(ShortcutCommand.previousTab.defaultCombination.ghosttyTriggers == ["ctrl+shift+tab"])
    #expect(
      ShortcutCommand.focusNextGroup.defaultCombination.ghosttyTriggers == ["super+alt+right"]
    )
  }

  /// Ghostty's defaults bind `super+[` by character, and a user's file may
  /// bind `super+bracket_left` by key; each unbinds only its own.
  @Test func punctuationIsSpelledByCharacterAndByName() {
    #expect(
      KeyCombination(.character("["), .command).ghosttyTriggers
        == ["super+[", "super+bracket_left"]
    )
  }

  /// Ghostty binds ⌘1 to ⌘8 under both the digit and the physical key.
  @Test func aDigitOrLetterIsSpelledByCharacterAndByItsKeysName() {
    #expect(
      KeyCombination(.character("1"), .command).ghosttyTriggers == ["super+1", "super+digit_1"]
    )
    #expect(
      KeyCombination(.character("k"), .command).ghosttyTriggers == ["super+k", "super+key_k"]
    )
  }

  /// Ghostty reads `>` as the step between a sequence's keys, so no trigger can
  /// name it; nothing in its defaults is on it either.
  @Test func theGreaterThanKeyHasNoTrigger() {
    #expect(KeyCombination(.character(">"), .command).ghosttyTriggers.isEmpty)
  }

  /// libghostty drops a line it refuses without a word, so a key the recorder
  /// takes and Ghostty cannot name would stay Ghostty's in a pane.
  @Test func everyRecordableKeyIsALineThePinnedLibghosttyAccepts() throws {
    let ascii = (0x21...0x7E).compactMap(UnicodeScalar.init).map(Character.init)
    let printable = ascii + Array("öäüßéèàçñ§°²µ")
    let keys: [ShortcutKey] =
      ShortcutKey.named.map(\.key) + ShortcutKey.functionNumbers.map(ShortcutKey.function)
      + printable.map(ShortcutKey.character)
    let lines = keys.flatMap { key in
      KeyCombination(key, [.command, .control, .option, .shift]).ghosttyTriggers.map { trigger in
        "keybind = \(trigger)=unbind"
      }
    }
    let diagnostics = try libghosttyDiagnostics(
      GhosttyUserConfig.defaults.rendered + "\n" + lines.joined(separator: "\n")
    )
    #expect(diagnostics.isEmpty, "\(diagnostics)")
  }
}
