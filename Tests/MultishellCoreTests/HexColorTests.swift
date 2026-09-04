import Testing

@testable import MultishellCore

@Suite
struct HexColorTests {
  @Test func parsesSixDigitHexWithAndWithoutHash() {
    #expect(HexColor.parse("#5aa9f8") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("5aa9f8") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
  }

  @Test func expandsThreeDigitShorthand() {
    #expect(HexColor.parse("#f0a") == RGB(red: 0xff, green: 0x00, blue: 0xaa))
  }

  @Test func rejectsMalformedInput() {
    #expect(HexColor.parse("") == nil)
    #expect(HexColor.parse("#12345") == nil)
    #expect(HexColor.parse("#gggggg") == nil)
  }

  @Test func surroundingWhitespaceIsForgiven() {
    #expect(HexColor.parse(" #5aa9f8 ") == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
    #expect(HexColor.parse("#5a a9f8") == nil, "but not a space inside")
  }

  @Test func aLeadingSignIsNotAColour() {
    // `UInt32(_:radix:)` accepts "+abcde" as 0xabcde; a theme file must not.
    #expect(HexColor.parse("#+abcde") == nil)
    #expect(HexColor.parse("+abcde") == nil)
    #expect(HexColor.parse("-abcde") == nil)
  }

  @Test func everyBuiltinThemeParsesCompletely() {
    for theme in Theme.builtins {
      #expect(
        theme.ansi.allSatisfy { HexColor.parse($0) != nil }, "\(theme.id) has a bad ANSI colour")
      #expect(HexColor.parse(theme.background) != nil)
      #expect(HexColor.parse(theme.foreground) != nil)
      #expect(HexColor.parse(theme.cursor) != nil)
      #expect(HexColor.parse(theme.selectionBackground) != nil)
    }
  }
}
