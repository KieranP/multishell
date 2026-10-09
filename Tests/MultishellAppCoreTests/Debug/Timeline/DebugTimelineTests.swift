import Testing

@testable import MultishellAppCore

@Suite
struct DebugTimelineTests {
  @Test func aFreshHistoryFillsFromTheRightWithEmptySlotsBeforeIt() {
    let timeline = DebugTimeline(
      history: .of((0..<3).map { DebugSample.sample(sequence: $0) }), range: .oneMinute)

    #expect(timeline.slots.count == 60)
    #expect(timeline.slots.prefix(57).allSatisfy { $0 == nil })
    #expect(timeline.slots.suffix(3).allSatisfy { $0 != nil })
    #expect(DebugTimeline(history: DebugHistory(), range: .oneMinute).slots.count == 60)
  }

  @Test func aSlotOfSeveralSecondsHoldsTheSameSecondsAsTheHistoryGrows() throws {
    let samples = (0..<12).map {
      DebugSample.sample(sequence: $0, framesPerSecond: $0 == 7 ? 30 : 120, gitRunsStartedCount: $0)
    }
    let early = DebugTimeline(history: .of(Array(samples.prefix(11))), range: .fifteenMinutes)
    let later = DebugTimeline(history: .of(samples), range: .fifteenMinutes)

    let slot = try #require(later.slots[later.slots.count - 2])
    #expect(slot == early.slots[early.slots.count - 2])
    #expect(slot.gitRunsStartedPerSecond == 7, "seconds 5 to 9")
  }

  @Test func aStallIsCountedPerSecondOverTheRangeAlone() {
    let samples = (0..<120).map {
      DebugSample.sample(sequence: $0, longestFrame: .milliseconds($0 == 10 || $0 > 115 ? 150 : 9))
    }
    #expect(DebugTimeline(history: .of(samples), range: .oneMinute).stalledSecondCount == 4)
    #expect(DebugTimeline(history: .of(samples), range: .fiveMinutes).stalledSecondCount == 5)
  }

  @Test func aStripIsScaledToItsPeakButNeverBelowItsFloor() throws {
    let samples = [
      DebugSample.sample(sequence: 0, gitRunsStartedCount: 2, appMemory: 100, childrenMemory: 300),
      DebugSample.sample(sequence: 1, gitRunsStartedCount: 4, appMemory: 200, childrenMemory: 900),
    ]
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)

    let git = try #require(timeline.points(of: .gitRuns).last ?? nil)
    #expect(git.total == 0.4, "ten runs a second is the least a strip shows")
    let memory = try #require(timeline.points(of: .memory).last ?? nil)
    #expect(abs(memory.total - 1 / 1.1) < 0.0001)
    #expect(abs(memory.app - 200 / 1_210) < 0.0001)
  }

  @Test func theMemoryStripStacksTheTerminalsBetweenTheAppAndItsChildren() throws {
    let samples = [
      DebugSample.sample(sequence: 0, appMemory: 400, terminalMemory: 150, childrenMemory: 700)
    ]
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)

    let memory = try #require(timeline.points(of: .memory).last ?? nil)
    #expect(abs(memory.app - 250 / 1_210) < 0.0001)
    #expect(abs(memory.appWithTerminals - 400 / 1_210) < 0.0001)
    #expect(abs(memory.total - 1_100 / 1_210) < 0.0001)
    let cpu = try #require(timeline.points(of: .cpu).last ?? nil)
    #expect(cpu.appWithTerminals == cpu.app)
  }

  @Test func aFractionAcrossTheStripNamesTheSlotUnderItClampedToTheEnds() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    #expect(timeline.slotIndex(atFraction: 0) == 0)
    #expect(timeline.slotIndex(atFraction: 0.5) == 30)
    #expect(timeline.slotIndex(atFraction: 1) == 59)
    #expect(timeline.slotIndex(atFraction: -2) == 0)
  }

  @Test func eachSlotsMidpointIsTheXThatNamesItAgain() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    for index in timeline.slots.indices {
      let x = 80 + timeline.slotMidpointX(index, chartWidth: 300)
      #expect(timeline.slotIndex(atX: x, labelWidth: 80, chartWidth: 300) == index)
    }
  }

  @Test func aPointerOverTheLabelsOrPastTheChartIsOverNoSlot() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    #expect(timeline.slotIndex(atX: 40, labelWidth: 50, chartWidth: 600) == nil)
    #expect(timeline.slotIndex(atX: 50, labelWidth: 50, chartWidth: 600) == 0)
    #expect(timeline.slotIndex(atX: 350, labelWidth: 50, chartWidth: 600) == 30)
    #expect(timeline.slotIndex(atX: 651, labelWidth: 50, chartWidth: 600) == nil)
    #expect(timeline.slotIndex(atX: 60, labelWidth: 50, chartWidth: 0) == nil, "not laid out yet")
  }

  @Test func aSlotAskedForPastTheRangeIsNoneRatherThanOutOfBounds() {
    let timeline = DebugTimeline(
      history: .of([DebugSample.sample(sequence: 0)]), range: .oneMinute)
    #expect(timeline.slot(at: 59) != nil)
    #expect(timeline.slot(at: 150) == nil, "a pointer left over from the fifteen minute range")
    #expect(timeline.slot(at: nil) == nil)
  }

  @Test func aStripShowsTheHoveredSlotAndOtherwiseTheLatest() throws {
    let samples = (0..<2).map { DebugSample.sample(sequence: $0, gitRunsStartedCount: $0 * 3) }
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)
    let latest = try #require(timeline.slots[59])
    let earlier = try #require(timeline.slots[58])

    #expect(timeline.shownSlot(hovering: 58) == earlier)
    #expect(timeline.shownSlot(hovering: nil) == latest)
    #expect(timeline.shownSlot(hovering: 150) == latest, "a pointer left from a longer range")
    #expect(timeline.shownSlot(hovering: 0) == latest, "an empty slot before the history began")
  }
}
