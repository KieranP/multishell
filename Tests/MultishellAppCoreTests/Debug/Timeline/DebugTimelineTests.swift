import Testing

@testable import MultishellAppCore

@Suite
struct DebugTimelineTests {
  @Test func aFreshHistoryFillsFromTheRightWithEmptySlotsBeforeIt() {
    let timeline = DebugTimeline(
      history: .of((0..<3).map { DebugSample.sample(sequence: $0) }),
      range: .oneMinute,
    )

    #expect(timeline.slots.count == 60)
    #expect(timeline.slots.prefix(57).allSatisfy { $0 == nil })
    #expect(timeline.slots.suffix(3).allSatisfy { $0 != nil })
    #expect(DebugTimeline(history: DebugHistory(), range: .oneMinute).slots.count == 60)
  }

  @Test func aSlotOfSeveralSecondsHoldsTheSameSecondsAsTheHistoryGrows() throws {
    let samples = (0..<12).map { sequence in
      DebugSample.sample(
        sequence: sequence,
        framesPerSecond: sequence == 7 ? 30 : 120,
        cliExecutionsStartedCount: sequence,
      )
    }
    let early = DebugTimeline(history: .of(Array(samples.prefix(11))), range: .fifteenMinutes)
    let later = DebugTimeline(history: .of(samples), range: .fifteenMinutes)

    let slot = try #require(later.slots[later.slots.count - 2])
    #expect(slot == early.slots[early.slots.count - 2])
    #expect(slot.cliExecutionsStartedPerSecond == 7, "seconds 5 to 9")
  }

  @Test func aFreezeCountsTheSecondsItHeldTheFrame() {
    let samples = [DebugSample.sample(sequence: 0, longestFrame: .seconds(10))]

    #expect(DebugTimeline(history: .of(samples), range: .oneMinute).stalledSecondCount == 10)
  }

  @Test func aFreezeLongerThanTheRangeCountsTheRangeAlone() {
    let samples = [DebugSample.sample(sequence: 0, longestFrame: .seconds(90))]

    #expect(DebugTimeline(history: .of(samples), range: .oneMinute).stalledSecondCount == 60)
  }

  @Test func aStallIsCountedPerSecondOverTheRangeAlone() {
    let samples = (0..<120).map { sequence in
      DebugSample.sample(
        sequence: sequence,
        longestFrame: .milliseconds(sequence == 10 || sequence > 115 ? 150 : 9),
      )
    }
    #expect(DebugTimeline(history: .of(samples), range: .oneMinute).stalledSecondCount == 4)
    #expect(DebugTimeline(history: .of(samples), range: .fiveMinutes).stalledSecondCount == 5)
  }

  @Test func aChartIsScaledToItsPeakButNeverBelowItsFloor() throws {
    let samples = [
      DebugSample.sample(
        sequence: 0,
        cliExecutionsStartedCount: 2,
        appMemory: 100,
        childrenMemory: 300,
      ),
      DebugSample.sample(
        sequence: 1,
        cliExecutionsStartedCount: 4,
        appMemory: 200,
        childrenMemory: 900,
      ),
    ]
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)

    let git = try #require(timeline.points(of: .cliActivity).last ?? nil)
    #expect(git.total == 0.4, "ten runs a second is the least a tile shows")
    let memory = try #require(timeline.points(of: .memory).last ?? nil)
    #expect(abs(memory.total - 1 / 1.1) < 0.0001)
    #expect(abs(memory.tops[0] - 200 / 1_210) < 0.0001)
  }

  @Test func theMemoryTileStacksTheTerminalsBetweenTheAppAndItsChildren() throws {
    let samples = [
      DebugSample.sample(sequence: 0, appMemory: 400, terminalMemory: 150, childrenMemory: 700)
    ]
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)

    let memory = try #require(timeline.points(of: .memory).last ?? nil)
    #expect(memory.tops.count == 3)
    #expect(abs(memory.tops[0] - 250 / 1_210) < 0.0001)
    #expect(abs(memory.tops[1] - 400 / 1_210) < 0.0001)
    #expect(abs(memory.total - 1_100 / 1_210) < 0.0001)
  }

  @Test func theCPUTileStacksTheMainThreadTerminalsOtherThreadsThenChildren() throws {
    let samples = [
      DebugSample.sample(
        sequence: 0,
        appCPUPercent: 40,
        childrenCPUPercent: 20,
        mainThreadCPUPercent: 25,
        terminalThreadsCPUPercent: 10,
      )
    ]
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)

    let cpu = try #require(timeline.points(of: .cpu).last ?? nil)
    #expect(cpu.tops == [0.25, 0.35, 0.4, 0.6])
  }

  @Test func aFractionAcrossTheChartNamesTheSlotUnderItClampedToTheEnds() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    #expect(timeline.slotIndex(atFraction: 0) == 0)
    #expect(timeline.slotIndex(atFraction: 0.5) == 30)
    #expect(timeline.slotIndex(atFraction: 1) == 59)
    #expect(timeline.slotIndex(atFraction: -2) == 0)
  }

  @Test func eachSlotsMidpointIsTheXThatNamesItAgain() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    for index in timeline.slots.indices {
      let x = timeline.slotMidpointX(index, chartWidth: 300)
      #expect(timeline.slotIndex(atX: x, chartWidth: 300) == index)
    }
  }

  @Test func aPointerPastEitherEndOfTheChartIsOverNoSlot() {
    let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
    #expect(timeline.slotIndex(atX: -1, chartWidth: 600) == nil)
    #expect(timeline.slotIndex(atX: 0, chartWidth: 600) == 0)
    #expect(timeline.slotIndex(atX: 300, chartWidth: 600) == 30)
    #expect(timeline.slotIndex(atX: 601, chartWidth: 600) == nil)
    #expect(timeline.slotIndex(atX: 10, chartWidth: 0) == nil, "not laid out yet")
  }

  @Test func aSlotAskedForPastTheRangeIsNoneRatherThanOutOfBounds() {
    let timeline = DebugTimeline(
      history: .of([DebugSample.sample(sequence: 0)]),
      range: .oneMinute,
    )
    #expect(timeline.slot(at: 59) != nil)
    #expect(timeline.slot(at: 150) == nil, "a pointer left over from the fifteen minute range")
    #expect(timeline.slot(at: nil) == nil)
  }

  @Test func aTileShowsTheHoveredSlotAndOtherwiseTheLatest() throws {
    let samples = (0..<2).map { sequence in
      DebugSample.sample(sequence: sequence, cliExecutionsStartedCount: sequence * 3)
    }
    let timeline = DebugTimeline(history: .of(samples), range: .oneMinute)
    let latest = try #require(timeline.slots[59])
    let earlier = try #require(timeline.slots[58])

    #expect(timeline.shownSlot(hovering: 58) == earlier)
    #expect(timeline.shownSlot(hovering: nil) == latest)
    #expect(timeline.shownSlot(hovering: 150) == latest, "a pointer left from a longer range")
    #expect(timeline.shownSlot(hovering: 0) == latest, "an empty slot before the history began")
  }

  @Test func aRangeHasStallsOnlyWhereASecondHadAFrameOverTheThreshold() {
    let stalled = (0..<3).map { sequence in
      DebugSample.sample(sequence: sequence, longestFrame: .milliseconds(sequence == 0 ? 9 : 150))
    }
    let smooth = (0..<3).map { DebugSample.sample(sequence: $0, longestFrame: .milliseconds(9)) }

    #expect(DebugTimeline(history: .of(stalled), range: .oneMinute).hasStalls)
    #expect(!DebugTimeline(history: .of(smooth), range: .oneMinute).hasStalls)
  }

  @Test func theWakeupsTileStacksPackageIdleInsideInterruptNotOnTopOfIt() throws {
    let counts = DebugActivityCounts(
      diskBytesRead: 0,
      diskBytesWritten: 0,
      interruptWakeups: 30,
      packageIdleWakeups: 8,
    )
    let timeline = DebugTimeline(
      history: .of([.sample(sequence: 0, activity: counts)]),
      range: .oneMinute,
    )

    let wakeups = try #require(timeline.points(of: .wakeups).last ?? nil)
    #expect(wakeups.tops == [8.0 / 30, 1], "eight of thirty, the whole thirty at the top")
  }
}
