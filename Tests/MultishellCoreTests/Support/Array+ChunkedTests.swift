import MultishellCore
import Testing

struct ArrayChunkedTests {
  @Test func runsKeepTheirOrderAndTheLastHoldsWhatIsLeft() {
    #expect([1, 2, 3, 4, 5].chunked(into: 2) == [[1, 2], [3, 4], [5]])
  }

  @Test func anEmptyArrayHasNoRuns() {
    #expect([Int]().chunked(into: 3).isEmpty)
  }
}
