import Testing

@testable import MultishellAppCore

@Suite
struct DebugTimelineWordingTests {
  @Test func theStallSummaryCountsStalledSecondsAndNamesTheThreshold() {
    let samples = (0..<3).map { sequence in
      DebugSample.sample(sequence: sequence, longestFrame: .milliseconds(sequence == 0 ? 9 : 150))
    }
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)
    #expect(timeline.stallSummary == "2 seconds with a frame over 100 ms")
    #expect(timeline.hasStalls)
  }

  @Test func aRangeWithNoStallSaysNoneAndHasNoStalls() {
    let samples = (0..<3).map { DebugSample.sample(sequence: $0, longestFrame: .milliseconds(9)) }
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)
    #expect(timeline.stallSummary == "0 seconds with a frame over 100 ms")
    #expect(!timeline.hasStalls)
  }
}
