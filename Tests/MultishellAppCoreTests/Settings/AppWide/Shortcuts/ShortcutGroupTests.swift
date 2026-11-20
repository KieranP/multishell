import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShortcutGroupTests {
  @Test func everyCommandIsOnExactlyOneCard() {
    let listed = ShortcutGroup.allCases.flatMap(\.commands)
    #expect(listed.count == ShortcutCommand.allCases.count)
    #expect(Set(listed) == Set(ShortcutCommand.allCases))
  }

  @Test func everyShortcutsPartHasCards() {
    for section in SettingsPage.shortcuts.sections(in: .allProjects) {
      #expect(!ShortcutGroup.groups(in: section).isEmpty, "\(section)")
    }
  }

  @Test func theEditPartDividesUndoFromThePasteboardAsItsMenuDoes() {
    let commands = ShortcutGroup.groups(in: .shortcutsEdit).map(\.commands)
    #expect(commands.prefix(2) == [[.undo, .redo], [.cut, .copy, .paste, .selectAll]])
  }

  @Test func onlyTheFirstCardOfEachPartHeadsIt() {
    for section in SettingsPage.shortcuts.sections(in: .allProjects) {
      let groups = ShortcutGroup.groups(in: section)
      let laterCards = Array(repeating: false, count: groups.count - 1)
      #expect(groups.map(\.headsItsPart) == [true] + laterCards, "\(section)")
    }
  }
}
