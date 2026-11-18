import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct ProcessActivityMeterTests {
  private func activity(read: UInt64, written: UInt64, wakeups: UInt64) -> ProcessActivity {
    ProcessActivity(
      diskBytesRead: read,
      diskBytesWritten: written,
      interruptWakeups: wakeups,
      packageIdleWakeups: wakeups / 2,
      peakFootprint: 0,
    )
  }

  @Test func eachReadingCountsWhatHappenedSinceTheLast() {
    var meter = ProcessActivityMeter()
    #expect(meter.takeReading(of: activity(read: 100, written: 200, wakeups: 10)) == .zero)

    let counts = meter.takeReading(of: activity(read: 150, written: 1_200, wakeups: 40))

    #expect(
      counts
        == DebugActivityCounts(
          diskBytesRead: 50,
          diskBytesWritten: 1_000,
          interruptWakeups: 30,
          packageIdleWakeups: 15,
        )
    )
  }

  @Test func aMissedReadingCountsFromTheLastOneThatLanded() {
    var meter = ProcessActivityMeter()
    _ = meter.takeReading(of: activity(read: 100, written: 0, wakeups: 0))
    #expect(meter.takeReading(of: nil) == .zero)

    #expect(
      meter.takeReading(of: activity(read: 300, written: 0, wakeups: 0)).diskBytesRead == 200
    )
  }
}
