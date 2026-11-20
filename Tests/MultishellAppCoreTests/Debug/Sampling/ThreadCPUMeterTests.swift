import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct ThreadCPUMeterTests {
  private let start = ContinuousClock.now

  private func thread(
    _ id: UInt64,
    _ name: String,
    cpuTime: Duration,
    isMain: Bool = false,
  ) -> ThreadUsage {
    ThreadUsage(id: id, name: name, isMain: isMain, cpuTime: cpuTime)
  }

  @Test func theFirstReadingHasNothingToMeasureFrom() {
    var meter = ThreadCPUMeter()
    #expect(
      meter.takeReading(of: [thread(1, "", cpuTime: .seconds(5), isMain: true)], at: start)
        == .unmeasured
    )
  }

  @Test func theMainThreadAndTheTerminalsEachTakeTheirShareOfTheTimeBetween() {
    var meter = ThreadCPUMeter()
    _ = meter.takeReading(
      of: [
        thread(1, "", cpuTime: .seconds(1), isMain: true), thread(2, "renderer", cpuTime: .zero),
        thread(3, "io", cpuTime: .zero), thread(4, "", cpuTime: .zero),
      ],
      at: start,
    )

    let reading = meter.takeReading(
      of: [
        thread(1, "", cpuTime: .milliseconds(1_250), isMain: true),
        thread(2, "renderer", cpuTime: .milliseconds(50)),
        thread(3, "io", cpuTime: .milliseconds(50)),
        thread(4, "", cpuTime: .milliseconds(100)),
      ],
      at: start + .milliseconds(500),
    )

    #expect(reading.mainPercent == 50)
    #expect(reading.terminalsPercent == 20)
  }

  @Test func threadsSharingANameAddUpUnderOneKeyApartFromTheMainThread() {
    var meter = ThreadCPUMeter()
    _ = meter.takeReading(of: [thread(1, "", cpuTime: .zero, isMain: true)], at: start)

    let reading = meter.takeReading(
      of: [
        thread(1, "", cpuTime: .milliseconds(10), isMain: true),
        thread(2, "", cpuTime: .milliseconds(20)), thread(3, "", cpuTime: .milliseconds(30)),
      ],
      at: start + .seconds(1),
    )

    #expect(
      reading.byThread[DebugThreadKey(group: .main, name: "")]
        == DebugThreadTally(threadCount: 1, cpuTime: .milliseconds(10))
    )
    #expect(
      reading.byThread[DebugThreadKey(group: .other, name: "")]
        == DebugThreadTally(threadCount: 2, cpuTime: .milliseconds(50))
    )
  }

  @Test func aThreadStartedSinceTheLastReadingCountsAllItSpent() {
    var meter = ThreadCPUMeter()
    _ = meter.takeReading(of: [thread(1, "", cpuTime: .zero, isMain: true)], at: start)

    let reading = meter.takeReading(
      of: [thread(9, "renderer", cpuTime: .milliseconds(300))],
      at: start + .seconds(1),
    )

    #expect(reading.terminalsPercent == 30)
  }

  @Test func aFailedThreadReadLeavesTheNextReadingMeasuredFromTheLastOneThatLanded() {
    var meter = ThreadCPUMeter()
    _ = meter.takeReading(of: [thread(1, "", cpuTime: .seconds(10), isMain: true)], at: start)

    #expect(meter.takeReading(of: [], at: start + .seconds(1)) == .unmeasured)
    let reading = meter.takeReading(
      of: [thread(1, "", cpuTime: .milliseconds(10_500), isMain: true)],
      at: start + .seconds(2),
    )

    #expect(reading.mainPercent == 25)
  }
}
