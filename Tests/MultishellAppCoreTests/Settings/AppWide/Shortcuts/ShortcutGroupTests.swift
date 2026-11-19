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
}
