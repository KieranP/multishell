import Testing

@testable import MultishellCore

extension HexColorTests {
  @Test func aTrailingAlphaIsReadAndIgnored() {
    #expect(HexColor.parse("#5aa9f8ff") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("5aa9f800") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("#f0f8") == RGB(red: 0xff, green: 0x00, blue: 0xff))
  }

  @Test func otherLengthsAndBadAlphaDigitsAreStillRefused() {
    for text in ["#5aa9f8f", "#5aa9f8fff", "#5aa9f8zz", "#f0fz", "#ab", "#abcde"] {
      #expect(HexColor.parse(text) == nil, "\(text)")
    }
  }
}
