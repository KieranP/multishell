import Testing

@testable import MultishellCore

@Suite
struct DictionaryKeepingFirstTests {
  @Test func aRepeatedKeyKeepsTheValueThatCameFirst() {
    let pairs = [("a", 1), ("b", 2), ("a", 3)]
    #expect(Dictionary(keepingFirst: pairs) == ["a": 1, "b": 2])
  }
}
