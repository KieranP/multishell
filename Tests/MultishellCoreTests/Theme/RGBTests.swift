import Testing

@testable import MultishellCore

@Suite
struct RGBTests {
  @Test func aColourWithAlphaLosesItForATerminal() {
    let faint = RGB(red: 0x5a, green: 0xa9, blue: 0xf8, alpha: 0x80)
    #expect(faint.opaqueHex == "#5aa9f8")
    #expect(faint.opaque == RGB(red: 0x5a, green: 0xa9, blue: 0xf8))
  }
}
