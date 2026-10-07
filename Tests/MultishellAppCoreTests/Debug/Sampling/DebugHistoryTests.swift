import Testing

@testable import MultishellAppCore

@Suite
struct DebugHistoryTests {
  @Test func theHistoryKeepsFifteenMinutesAndARangeTakesItsNewestSeconds() {
    let history = DebugHistory.of((0..<1_000).map { DebugSample.sample(sequence: $0) })

    #expect(history.samples.count == 900)
    #expect(history.samples.first?.sequence == 100)
    #expect(history.samples(in: .oneMinute).map(\.sequence) == Array(940..<1_000))
    #expect(history.nextSequence == 1_000)
    #expect(DebugHistory().nextSequence == 0)
  }
}
