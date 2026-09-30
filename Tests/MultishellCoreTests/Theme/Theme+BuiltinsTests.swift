import Testing

@testable import MultishellCore

@Suite
struct ThemeBuiltinsTests {
  @Test func everyBuiltinThemeParsesCompletely() {
    for theme in Theme.builtins {
      #expect(
        theme.ansi.allSatisfy { HexColor.parse($0) != nil }, "\(theme.id) has a bad ANSI colour")
      #expect(HexColor.parse(theme.background) != nil)
      #expect(HexColor.parse(theme.foreground) != nil)
      #expect(HexColor.parse(theme.cursor) != nil)
      #expect(HexColor.parse(theme.selectionBackground) != nil)
      #expect(theme.focusRingRGB != nil, "\(theme.id) draws no focus ring")
      #expect(
        theme.focusRingRGB != theme.selectionBackgroundRGB,
        "\(theme.id) rings in its selection colour, which is mixed to sit under text")
      #expect(
        theme.inactivePaneOpacity > Theme.minimumInactivePaneOpacity
          && theme.inactivePaneOpacity < 1,
        "\(theme.id) fades unfocused panes by nothing, or by all")
    }
  }
}
