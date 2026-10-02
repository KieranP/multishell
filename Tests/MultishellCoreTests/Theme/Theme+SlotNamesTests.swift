import Testing

@testable import MultishellCore

@Suite
struct ThemeSlotNamesTests {
  @Test func everyAnsiSlotHasAName() {
    #expect(Theme.ansiSlotNames.count == Theme.ansiSlotCount)
  }
}
