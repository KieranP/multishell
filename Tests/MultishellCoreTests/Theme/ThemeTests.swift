import Foundation
import Testing

@testable import MultishellCore

struct ThemeTests {
  @Test func aThemeWithTheWrongNumberOfColoursIsRefused() throws {
    var fifteen = Theme.multishellDark
    fifteen.ansi.removeLast()
    let json = try JSONEncoder().encode(fifteen)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Theme.self, from: json) }
    let full = try JSONEncoder().encode(Theme.multishellDark)
    #expect(try JSONDecoder().decode(Theme.self, from: full) == Theme.multishellDark)
  }

  /// Both keys have to default, or every theme file written before they
  /// existed, and every one spelling them wrong, stops loading.
  @Test func aThemeWithoutAFocusRingOrAFadeStillLoads() throws {
    let bare = try decodeJSON(
      Theme.self,
      #"""
      { "id": "bare", "name": "Bare", "isDark": true, "background": "#000000",
        "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
        "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
      """#)
    #expect(bare.focusRing == nil)
    #expect(
      bare.focusRingRGB == bare.selectionBackgroundRGB, "the key left out is the selection colour")
    #expect(bare.inactivePaneOpacity == 1, "nothing fades until a theme asks for it")

    let wrongTypes = try decodeJSON(
      Theme.self,
      #"""
      { "id": "odd", "name": "Odd", "isDark": true, "background": "#000000",
        "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
        "focusRing": 12, "inactivePaneOpacity": "half",
        "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
      """#)
    #expect(wrongTypes.focusRingRGB == wrongTypes.selectionBackgroundRGB)
    #expect(wrongTypes.inactivePaneOpacity == 1)
  }

  /// A fade nobody can read through is not a signal, so the value is
  /// clamped rather than taken at its word.
  @Test func aFadeOutsideTheUsableRangeIsClamped() throws {
    func opacity(_ value: String) throws -> Double {
      try decodeJSON(
        Theme.self,
        #"""
        { "id": "x", "name": "X", "isDark": true, "background": "#000000",
          "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a",
          "inactivePaneOpacity": \#(value),
          "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
        """#
      ).inactivePaneOpacity
    }
    #expect(try opacity("0") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("-4") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("2") == 1)
    #expect(try opacity("0.6") == 0.6)
  }

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
