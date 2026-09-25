import Testing

@testable import MultishellCore

@Suite
struct ArrayNeighbourTests {
  @Test func aNeighbourWrapsAtBothEndsAndAnArrayOfOneHasNone() {
    struct Item: Identifiable { let id: Int }
    let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
    #expect(items.neighbour(of: 3, .next)?.id == 1)
    #expect(items.neighbour(of: 1, .previous)?.id == 3)
    #expect(items.neighbour(of: 2, .next)?.id == 3)
    #expect(items.neighbour(of: 9, .next) == nil)
    #expect([Item(id: 1)].neighbour(of: 1, .next) == nil)
  }
}
