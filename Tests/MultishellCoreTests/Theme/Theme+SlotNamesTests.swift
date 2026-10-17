import Testing

@testable import MultishellCore

@Suite
struct ThemeSlotNamesTests {
  @Test func everyProjectIconSlotHasAName() {
    #expect(Theme.projectIconSlotNames.count == Theme.ansiSlotCount)
    #expect(Set(Theme.projectIconSlotNames).count == Theme.ansiSlotCount)
    #expect(!Theme.projectIconSlotNames.contains { $0.hasPrefix("ansi.") }, "a key with no entry")
  }
}
