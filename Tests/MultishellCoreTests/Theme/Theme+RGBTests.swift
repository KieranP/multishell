import Testing

@testable import MultishellCore

/// The focus ring reads three spellings of one key; see `Theme.focusRing`.
@Suite
struct ThemeRGBTests {
  private func theme(ring: String?) -> Theme {
    var theme = Theme.multishellDark
    theme.focusRing = ring
    return theme
  }

  @Test func aColourIsThatColour() {
    #expect(theme(ring: "#6cc763").focusRingRGB == RGB(red: 0x6c, green: 0xc7, blue: 0x63))
    #expect(theme(ring: " 6cc763 ").focusRingRGB == RGB(red: 0x6c, green: 0xc7, blue: 0x63))
  }

  @Test func anEmptyStringIsNoRingAtAll() {
    #expect(theme(ring: "").focusRingRGB == nil)
    #expect(theme(ring: "   ").focusRingRGB == nil, "whitespace is how a JSON file says empty")
  }

  @Test func theKeyLeftOutIsTheSelectionColour() {
    #expect(theme(ring: nil).focusRingRGB == Theme.multishellDark.selectionBackgroundRGB)
  }

  /// A typo costs the colour, not the ring: reading it as off would
  /// silently remove the thing the key was setting.
  @Test func aColourThatWillNotParseFallsBackRatherThanTurningTheRingOff() {
    #expect(theme(ring: "cornflower").focusRingRGB == Theme.multishellDark.selectionBackgroundRGB)
    #expect(theme(ring: "#12345").focusRingRGB == Theme.multishellDark.selectionBackgroundRGB)
  }

  @Test func oneAnsiSlotReadsAsTheWholeListDoesAndOneOutOfRangeIsGrey() throws {
    var theme = try #require(Theme.builtins.first)
    theme.ansi[3] = "not a colour"
    let grey = RGB(red: 128, green: 128, blue: 128)

    #expect(theme.ansi.indices.allSatisfy { theme.ansiRGB($0) == theme.ansiRGB[$0] })
    #expect(theme.ansiRGB(3) == grey)
    #expect(theme.ansiRGB(99) == grey)
  }
}
