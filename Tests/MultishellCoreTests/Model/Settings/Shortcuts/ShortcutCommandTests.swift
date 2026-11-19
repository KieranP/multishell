import Testing

@testable import MultishellCore

@Suite
struct ShortcutCommandTests {
  @Test func noTwoCommandsDefaultToTheSameKeys() {
    let defaults = ShortcutCommand.allCases.map(\.defaultCombination)
    #expect(Set(defaults).count == defaults.count, "\(defaults.map(\.glyphs))")
  }

  @Test func noDefaultIsOnKeysTheSystemKeeps() {
    for command in ShortcutCommand.allCases {
      #expect(ReservedShortcut.holding(command.defaultCombination) == nil, "\(command)")
    }
  }

  @Test func theEditMenusUniversalCommandsAreFixed() {
    #expect(
      Set(ShortcutCommand.allCases.filter(\.isFixed))
        == [.undo, .redo, .find, .cut, .copy, .paste, .selectAll]
    )
  }

  @Test func onlyTheClipboardCommandsKeepTheirKeysInAPane() {
    #expect(
      Set(ShortcutCommand.allCases.filter(\.surfaceKeepsBinding))
        == [.cut, .copy, .paste, .selectAll]
    )
  }
}
