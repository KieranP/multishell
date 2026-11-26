import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct DebugValueTextTests {
  private let english = Locale(identifier: "en_US")

  @Test func aDurationReadsInMillisecondsUnderASecondAndTenthsOfASecondFromOne() {
    #expect(DebugValueText.duration(.milliseconds(148)) == "148 ms")
    #expect(DebugValueText.duration(.milliseconds(3_140)) == "3.1 s")
  }

  @Test func aRateShowsTenthsOnlyWhereItComesToAFraction() {
    #expect(DebugValueText.perSecond(4) == "4/s")
    #expect(DebugValueText.perSecond(2.4) == "2.4/s")
  }

  @Test func memoryFromAThousandBytesUpShowsTwoDecimalPlaces() {
    #expect(DebugValueText.memory(1_536, locale: english) == "1.50 KB")
    #expect(DebugValueText.memory(15 << 20, locale: english) == "15.00 MB")
    #expect(DebugValueText.memory(UInt64(267.8 * 1_048_576), locale: english) == "267.80 MB")
    #expect(DebugValueText.memory(UInt64(1.9 * 1_073_741_824), locale: english) == "1.90 GB")
    #expect(DebugValueText.memory(5 << 40, locale: english) == "5.00 TB")
  }

  @Test func memoryMovesUpAUnitAtAThousandSoNoFigureNeedsFourWholeDigits() {
    #expect(DebugValueText.memory(1_000, locale: english) == "0.98 KB")
    #expect(DebugValueText.memory(999 << 20, locale: english) == "999.00 MB")
    #expect(DebugValueText.memory(1_000 << 20, locale: english) == "0.98 GB")
    #expect(DebugValueText.memory((1_000 << 20) - 1, locale: english) == "0.98 GB")
  }

  @Test func memoryUnderAThousandBytesStaysInWholeBytes() {
    #expect(DebugValueText.memory(500, locale: english) == "500 bytes")
  }

  @Test func memoryWritesItsFractionTheRegionsWay() {
    #expect(DebugValueText.memory(1_536, locale: Locale(identifier: "de_DE")) == "1,50 KB")
  }

  @Test func framesAndPercentagesAreWholeNumbers() {
    #expect(DebugValueText.framesPerSecond(59.6) == "60 fps")
    #expect(DebugValueText.percent(33.4) == "33%")
  }
}
