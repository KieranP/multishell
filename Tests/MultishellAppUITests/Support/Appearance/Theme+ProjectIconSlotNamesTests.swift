import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite
struct ThemeProjectIconSlotNamesTests {
  @Test func everyProjectIconSlotHasAName() {
    #expect(Theme.projectIconSlotNames.count == Theme.ansiSlotCount)
    #expect(Set(Theme.projectIconSlotNames).count == Theme.ansiSlotCount)
    #expect(!Theme.projectIconSlotNames.contains { $0.hasPrefix("ansi.") }, "a key with no entry")
  }
}
