import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

struct AllChangesHighlightCacheTests {
  private static let text = DiffDisplayText(
    [DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "a")],
    marksStaging: true,
  )

  private static func key(_ index: Int) -> AllChangesHighlightKey {
    AllChangesHighlightKey(path: "f\(index).swift", side: nil)
  }

  @Test func pastItsCapacityTheOldestParseGoesAndTheNewestStay() {
    var cache = AllChangesHighlightCache()

    for index in 0...AllChangesHighlightCache.capacity {
      cache.keep([], of: Self.key(index), for: Self.text)
    }

    #expect(cache.spans(of: Self.key(0), for: Self.text) == nil)
    #expect(cache.spans(of: Self.key(1), for: Self.text) != nil)
    #expect(cache.spans(of: Self.key(AllChangesHighlightCache.capacity), for: Self.text) != nil)
  }
}
