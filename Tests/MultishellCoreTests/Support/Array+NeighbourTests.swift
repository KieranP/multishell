import Testing

@testable import MultishellCore

@Suite
struct ArrayNeighbourTests {
  @Test func aNeighbourWrapsAtBothEndsAndAnArrayOfOneHasNone() {
    struct Item: Identifiable { let id: Int }
    let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
    #expect(items.neighbour(of: 3, .after)?.id == 1)
    #expect(items.neighbour(of: 1, .before)?.id == 3)
    #expect(items.neighbour(of: 2, .after)?.id == 3)
    #expect(items.neighbour(of: 9, .after) == nil)
    #expect([Item(id: 1)].neighbour(of: 1, .after) == nil)
  }
}
