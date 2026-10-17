import Testing

@testable import MultishellCore

@Suite
struct ThemeColorsTests {
  private let dark = Theme.multishellDark

  private func theme(_ key: TerminalColorKey, _ text: String?) -> Theme {
    var theme = dark
    theme.terminalColors[key] = text
    return theme
  }

  @Test func aHexRingReadsAsItsColourWithOrWithoutTheHashAndSpaces() {
    let green = RGB(red: 0x6c, green: 0xc7, blue: 0x63)
    #expect(theme(.focusRing, "#6cc763").terminalRGB(.focusRing) == green)
    #expect(theme(.focusRing, " 6cc763 ").terminalRGB(.focusRing) == green)
  }

  @Test func anEmptyRingIsNoRingThoughTheBaseDrawsOne() {
    #expect(theme(.focusRing, "").terminalRGB(.focusRing) == nil)
    #expect(theme(.focusRing, "   ").terminalRGB(.focusRing) == nil)
  }

  @Test func aCursorOrSelectionTextColourSetOverTheBasesNoneIsDrawn() {
    let green = RGB(red: 0x6c, green: 0xc7, blue: 0x63)
    for key in [TerminalColorKey.cursorText, .selectionForeground] {
      #expect(dark.terminalRGB(key) == nil, "\(key)")
      #expect(theme(key, "#6cc763").terminalRGB(key) == green, "\(key)")
    }
  }

  @Test func anEmptyStringForAColourEveryTerminalNeedsIsTheBases() {
    #expect(theme(.background, "").terminalRGB(.background) == dark.terminalRGB(.background))
  }

  @Test func aRingThatWillNotParseIsTheBasesRatherThanNone() {
    #expect(
      theme(.focusRing, "cornflower").terminalRGB(.focusRing) == dark.terminalRGB(.focusRing)
    )
    #expect(theme(.focusRing, nil).terminalRGB(.focusRing) == dark.terminalRGB(.focusRing))
  }

  @Test func anAgentMarkSetToEmptyOrUnknownTakesTheTextAroundIt() {
    var theme = dark
    theme.agentMarkColors["claude"] = ""
    #expect(theme.agentMarkRGB("claude") == nil)
    #expect(dark.agentMarkRGB("claude") != nil)
    #expect(dark.agentMarkRGB("codex") == nil)
    #expect(dark.agentMarkRGB("wezterm-agent") == nil)
  }

  @Test func anAnsiSlotOutOfRangeIsGrey() {
    #expect(dark.ansiRGB(99) == RGB(red: 128, green: 128, blue: 128))
  }
}
