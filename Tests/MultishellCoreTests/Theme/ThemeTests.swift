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
    let bare = try theme()
    #expect(bare.focusRing == nil)
    #expect(
      bare.focusRingRGB == bare.selectionBackgroundRGB, "the key left out is the selection colour")
    #expect(bare.inactivePaneOpacity == 1, "nothing fades until a theme asks for it")

    let wrongTypes = try theme(adding: #""focusRing": 12, "inactivePaneOpacity": "half","#)
    #expect(wrongTypes.focusRingRGB == wrongTypes.selectionBackgroundRGB)
    #expect(wrongTypes.inactivePaneOpacity == 1)
  }

  /// A fade nobody can read through is not a signal, so the value is
  /// clamped rather than taken at its word.
  @Test func aFadeOutsideTheUsableRangeIsClamped() throws {
    func opacity(_ value: String) throws -> Double {
      try theme(adding: #""inactivePaneOpacity": \#(value),"#).inactivePaneOpacity
    }
    #expect(try opacity("0") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("-4") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("2") == 1)
    #expect(try opacity("0.6") == 0.6)
  }

  /// A theme file holding only the keys every theme must, plus `keys`, each
  /// ending in a comma.
  private func theme(adding keys: String = "") throws -> Theme {
    try decodeJSON(
      Theme.self,
      #"""
      { "id": "x", "name": "X", "isDark": true, "background": "#000000",
        "foreground": "#ffffff", "cursor": "#ffffff", "selectionBackground": "#2f4f7a", \#(keys)
        "ansi": ["#000"\#(String(repeating: ",\"#000\"", count: 15))] }
      """#)
  }
}
