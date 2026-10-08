import Testing

@testable import MultishellCore

@Suite
struct ThemeSlotNamesTests {
  @Test func everyAnsiSlotHasAName() {
    #expect(Theme.ansiSlotNames.count == Theme.ansiSlotCount)
    #expect(Set(Theme.ansiSlotNames).count == Theme.ansiSlotCount)
    #expect(!Theme.ansiSlotNames.contains { $0.hasPrefix("ansi.") }, "a key with no entry")
  }
}
