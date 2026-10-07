import Testing

@testable import MultishellAppCore

@Suite
struct FrameRateMeterTests {
  private let start = ContinuousClock.now

  @Test func aReadingCountsFramesOverTheTimeSinceTheLastAndKeepsTheLongestGap() throws {
    var meter = FrameRateMeter()
    let first = meter.takeReading(at: start)
    #expect(first == nil)
    for millisecond in [8, 16, 24, 250, 258] {
      meter.noteFrame(at: start + .milliseconds(millisecond))
    }

    let measured = meter.takeReading(at: start + .milliseconds(500))
    let reading = try #require(measured)
    #expect(reading.framesPerSecond == 10)
    #expect(reading.longestFrame == .milliseconds(226))
  }

  @Test func theGapAcrossTwoReadingsCountsInTheSecondAndAQuietSecondReadsNothing() throws {
    var meter = FrameRateMeter()
    _ = meter.takeReading(at: start)
    meter.noteFrame(at: start + .milliseconds(900))
    _ = meter.takeReading(at: start + .seconds(1))
    meter.noteFrame(at: start + .milliseconds(1_300))

    let measured = meter.takeReading(at: start + .seconds(2))
    let reading = try #require(measured)
    #expect(reading.longestFrame == .milliseconds(400))
    let quiet = meter.takeReading(at: start + .seconds(3))
    #expect(quiet == nil)
  }

  @Test func framesThatStopWhileReadingsCameOnTimeAreADisplayAsleepNotAStall() throws {
    var meter = FrameRateMeter()
    _ = meter.takeReading(at: start)
    meter.noteFrame(at: start + .milliseconds(900))
    _ = meter.takeReading(at: start + .seconds(1))
    _ = meter.takeReading(at: start + .seconds(2))
    _ = meter.takeReading(at: start + .seconds(3))
    meter.noteFrame(at: start + .milliseconds(3_500))
    meter.noteFrame(at: start + .milliseconds(3_508))

    let measured = meter.takeReading(at: start + .seconds(4))
    let reading = try #require(measured)
    #expect(reading.longestFrame == .milliseconds(8))
  }

  @Test func aReadingHeldLateByAStallKeepsTheGapForTheNextFrame() throws {
    var meter = FrameRateMeter()
    _ = meter.takeReading(at: start)
    meter.noteFrame(at: start + .milliseconds(900))
    _ = meter.takeReading(at: start + .seconds(1))
    _ = meter.takeReading(at: start + .milliseconds(3_500))
    meter.noteFrame(at: start + .milliseconds(3_501))

    let measured = meter.takeReading(at: start + .milliseconds(4_500))
    let reading = try #require(measured)
    #expect(reading.longestFrame == .milliseconds(2_601))
  }
}
