import Testing

@testable import MultishellCore

@Suite
struct SequenceMapConcurrentlyUnorderedTests {
  @Test func everyElementIsTransformedExactlyOnce() async {
    let results = await Array(1...20).mapConcurrentlyUnordered(width: 3) { $0 * 2 }
    #expect(results.sorted() == Array(1...20).map { $0 * 2 })
  }

  @Test func noMoreThanTheWidthRunAtOnce() async {
    let gauge = ConcurrencyGauge()
    await Array(1...12).mapConcurrentlyUnordered(width: 3) { _ in
      await gauge.enter()
      for _ in 0..<20 { await Task.yield() }
      await gauge.leave()
    }
    #expect(await gauge.peak <= 3)
    #expect(await gauge.peak > 0)
  }
}
