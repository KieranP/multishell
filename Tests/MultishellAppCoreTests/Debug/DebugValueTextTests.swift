import Testing

@testable import MultishellAppCore

@Suite
struct DebugValueTextTests {
  @Test func aDurationReadsInMillisecondsUnderASecondAndTenthsOfASecondFromOne() {
    #expect(DebugValueText.duration(.milliseconds(148)) == "148 ms")
    #expect(DebugValueText.duration(.milliseconds(3_140)) == "3.1 s")
  }

  @Test func aRateShowsTenthsOnlyWhereItComesToAFraction() {
    #expect(DebugValueText.perSecond(4) == "4/s")
    #expect(DebugValueText.perSecond(2.4) == "2.4/s")
  }

  @Test func framesAndPercentagesAreWholeNumbers() {
    #expect(DebugValueText.framesPerSecond(59.6) == "60 fps")
    #expect(DebugValueText.percent(33.4) == "33%")
  }
}
