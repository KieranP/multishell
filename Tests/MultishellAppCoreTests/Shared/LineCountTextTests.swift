import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct LineCountTextTests {
  @Test func aCountOfFourDigitsReadsUnseparatedAndOneOfFiveIsGrouped() {
    let english = Locale(identifier: "en_US")

    #expect(LineCountText.shown(9_999, locale: english) == "9999")
    #expect(LineCountText.shown(16_621, locale: english) == "16,621")
    #expect(LineCountText.shown(1_234_567, locale: english) == "1,234,567")
  }
}
