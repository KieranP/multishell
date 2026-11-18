import Testing

@testable import MultishellAppCore

@Suite
struct DebugWorkTallyTests {
  @Test func aTallyCountsTheRunsTheirTimeTheSlowestAndWhatTheyWrote() {
    var tally = DebugWorkTally.empty
    tally.add(.milliseconds(3), bytesWritten: 1_000)
    tally.add(.milliseconds(9), bytesWritten: 500)

    #expect(tally.count == 2)
    #expect(tally.totalDuration == .milliseconds(12))
    #expect(tally.meanDuration == .milliseconds(6))
    #expect(tally.slowestDuration == .milliseconds(9))
    #expect(tally.bytesWritten == 1_500)
  }

  @Test func mergedTalliesAddUpAndKeepTheSlowestOfEither() {
    var first = DebugWorkTally.empty
    first.add(.milliseconds(2))
    var second = DebugWorkTally.empty
    second.add(.milliseconds(7), bytesWritten: 10)

    first.merge(second)

    #expect(first.count == 2)
    #expect(first.slowestDuration == .milliseconds(7))
    #expect(first.bytesWritten == 10)
  }

  @Test func anEmptyTallyHasNoMean() {
    #expect(DebugWorkTally.empty.meanDuration == .zero)
  }
}
