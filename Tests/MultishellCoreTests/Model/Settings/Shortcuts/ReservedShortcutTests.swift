import Testing

@testable import MultishellCore

@Suite
struct ReservedShortcutTests {
  @Test func theDocksHidingKeysAreReservedSoNoCommandSitsOnThem() {
    #expect(
      ReservedShortcut.holding(KeyCombination(.character("d"), [.command, .option])) == .dockHiding
    )
  }

  @Test func noTwoReservedEntriesNameTheSameKeys() {
    let combinations = ReservedShortcut.allCases.map(\.combination)
    #expect(Set(combinations).count == combinations.count)
  }
}
