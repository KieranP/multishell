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

  @Test func aNilStopsTheMapAndStartsNothingAfterIt() async {
    let gauge = ConcurrencyGauge()
    let results = await Array(1...20).mapConcurrentlyUnorderedStoppingAtNil(width: 1) { number in
      await gauge.enter()
      await gauge.leave()
      return number == 2 ? nil : number
    }

    #expect(results == nil)
    #expect(await gauge.entered == 2)
  }

  @Test func withNoNilEveryResultComesBack() async {
    let results = await Array(1...5).mapConcurrentlyUnorderedStoppingAtNil(width: 2) { $0 }
    #expect(results?.sorted() == Array(1...5))
  }
}
