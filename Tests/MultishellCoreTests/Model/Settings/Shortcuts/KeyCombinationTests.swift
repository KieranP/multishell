import Testing

@testable import MultishellCore

@Suite
struct KeyCombinationTests {
  @Test func aCharacterIsKeptLowercaseShiftBeingAModifierOfItsOwn() {
    #expect(
      KeyCombination(.character("K"), .command) == KeyCombination(.character("k"), .command)
    )
  }
}
