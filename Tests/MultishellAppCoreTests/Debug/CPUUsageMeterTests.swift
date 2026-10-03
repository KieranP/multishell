import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct CPUUsageMeterTests {
  private let start = ContinuousClock.now

  @Test func aShareIsTheCPUTimeSpentSinceTheLastReadingOverTheTimeBetween() {
    var meter = CPUUsageMeter()
    #expect(
      meter.takeReading(of: [.sample(pid: 1, cpuTime: .seconds(5))], at: start).byPID == [1: 0])

    let shares = meter.takeReading(
      of: [.sample(pid: 1, cpuTime: .milliseconds(6_500)), .sample(pid: 2, cpuTime: .seconds(9))],
      at: start + .milliseconds(500)
    ).byPID

    #expect(shares[1] == 300)
    #expect(shares[2] == 0, "first seen, with nothing to measure from")
  }

  @Test func aPidReusedWithLessTimeThanBeforeReadsNothingRatherThanBelowZero() {
    var meter = CPUUsageMeter()
    _ = meter.takeReading(of: [.sample(pid: 1, cpuTime: .seconds(5))], at: start)
    let shares = meter.takeReading(
      of: [.sample(pid: 1, cpuTime: .seconds(1))], at: start + .seconds(1)
    ).byPID
    #expect(shares[1] == 0)
  }

  @Test func aChildThatStartedAndExitedBetweenReadingsCountsAllItSpent() {
    var meter = CPUUsageMeter()
    _ = meter.takeReading(of: [], at: start)
    let reading = meter.takeReading(
      of: [], exited: [(pid: 7, cpuTime: .milliseconds(500))], at: start + .seconds(1))
    #expect(reading.exitedPercent == 50)
  }

  @Test func aChildTheLastReadingSawCountsOnlyWhatItSpentSince() {
    var meter = CPUUsageMeter()
    _ = meter.takeReading(of: [.sample(pid: 7, cpuTime: .seconds(1))], at: start)
    let reading = meter.takeReading(
      of: [], exited: [(pid: 7, cpuTime: .milliseconds(1_250))], at: start + .seconds(1))
    #expect(reading.exitedPercent == 25)
  }

  @Test func aChildThisReadingSawBeforeItExitedIsNotCountedTwice() {
    var meter = CPUUsageMeter()
    _ = meter.takeReading(of: [.sample(pid: 7, cpuTime: .seconds(1))], at: start)
    let reading = meter.takeReading(
      of: [.sample(pid: 7, cpuTime: .milliseconds(1_500))],
      exited: [(pid: 7, cpuTime: .milliseconds(1_750))], at: start + .seconds(1))
    #expect(reading.byPID[7] == 50)
    #expect(reading.exitedPercent == 25)
  }
}
