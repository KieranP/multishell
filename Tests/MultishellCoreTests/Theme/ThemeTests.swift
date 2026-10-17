import Foundation
import Testing

@testable import MultishellCore

struct ThemeTests {
  private let dark = Theme.multishellDark
  private let mint = RGB(red: 0xa0, green: 0xf0, blue: 0xc0)

  @Test func aThemeWithOnlyAnIdAndNameDrawsAsMultishellDark() throws {
    let bare = try theme("")
    #expect(bare.isDark)
    for key in FileColorKey.allCases { #expect(bare.fileRGB(key) == dark.fileRGB(key), "\(key)") }
    for section in InterfaceSection.allCases {
      for key in section.colorKeys {
        #expect(bare.interfaceRGB(key, in: section) == dark.interfaceRGB(key, in: section))
      }
    }
    for key in TerminalColorKey.allCases { #expect(bare.terminalRGB(key) == dark.terminalRGB(key)) }
    #expect(bare.inactivePaneOpacity == dark.inactivePaneOpacity)
  }

  @Test func aThemeWrittenBeforeSectionsIsRefusedRatherThanDrawnAsTheBase() {
    let flat = ##"{ "id": "x", "name": "X", "isDark": true, "background": "#000000", "ansi": [] }"##
    #expect(throws: DecodingError.self) { try decodeJSON(Theme.self, flat) }
  }

  @Test func aLightThemeFallsBackOnMultishellLight() throws {
    let light = try theme(#""is_dark": false"#)
    #expect(light.fileRGB(.background) == Theme.multishellLight.fileRGB(.background))
    #expect(
      light.interfaceRGB(.working, in: .states)
        == Theme.multishellLight.interfaceRGB(.working, in: .states)
    )
  }

  @Test func fileAndUIColoursNeverFollowTheThemesOwnTerminal() throws {
    let theme = try theme(
      ##""terminal": { "background": "#a0f0c0", "foreground": "#a0f0c0", "ansi": { "green": "#a0f0c0" } }"##
    )
    #expect(theme.terminalRGB(.background) == mint)
    #expect(theme.ansiRGB(2) == mint)
    #expect(theme.fileRGB(.background) == dark.fileRGB(.background))
    #expect(theme.fileRGB(.string) == dark.fileRGB(.string))
    #expect(theme.interfaceRGB(.added, in: .git) == dark.interfaceRGB(.added, in: .git))
    #expect(
      theme.interfaceRGB(.background, in: .projectsPanel)
        == dark.interfaceRGB(.background, in: .projectsPanel)
    )
  }

  @Test func oneAreaSetLeavesEveryOtherAtTheBase() throws {
    let theme = try theme(##""ui": { "projects_panel": { "background": "#a0f0c0" } }"##)
    #expect(theme.interfaceRGB(.background, in: .projectsPanel) == mint)
    #expect(
      theme.interfaceRGB(.background, in: .filesPanel)
        == dark.interfaceRGB(.background, in: .filesPanel)
    )
    #expect(
      theme.interfaceRGB(.text, in: .projectsPanel) == dark.interfaceRGB(.text, in: .projectsPanel)
    )
  }

  @Test func anEightDigitColourKeepsItsAlphaAndASixDigitOneIsOpaque() throws {
    let theme = try theme(##""file": { "comment": "#a0f0c080", "keyword": "#a0f0c0" }"##)
    #expect(theme.fileRGB(.comment) == RGB(red: 0xa0, green: 0xf0, blue: 0xc0, alpha: 0x80))
    #expect(theme.fileRGB(.keyword) == mint)
  }

  @Test func aColourThatWillNotParseOrIsOfTheWrongTypeIsTheBases() throws {
    let theme = try theme(##""file": { "comment": 12, "keyword": "teal", "string": "" }"##)
    for key in [FileColorKey.comment, .keyword, .string] {
      #expect(theme.fileRGB(key) == dark.fileRGB(key), "\(key)")
    }
  }

  @Test func aKeyItsSectionDoesNotTakeIsNeverRead() throws {
    let theme = try theme(##""ui": { "tab_bar": { "fill": "#a0f0c0", "selection": "#a0f0c0" } }"##)
    #expect(theme.interfaceColors[.tabBar] == [.selection: "#a0f0c0"])
  }

  @Test func aSectionThatIsNotAnObjectSetsNothing() throws {
    let theme = try theme(##""terminal": [1], "file": "#ff0000", "ui": { "header": 3 }"##)
    #expect(theme.terminalColors.isEmpty && theme.fileColors.isEmpty)
    #expect(theme.interfaceColors.isEmpty)
  }

  @Test func theAnsiAndProjectIconMapsAreReadByName() throws {
    let theme = try theme(
      ##""terminal": { "ansi": { "bright_white": "#a0f0c0" } }, "ui": { "project_icons": { "black": "#a0f0c0" } }"##
    )
    #expect(theme.ansiRGB(15) == mint)
    #expect(theme.ansiRGB(0) == dark.ansiRGB(0))
    #expect(theme.projectIconRGB(0) == mint)
    #expect(theme.projectIconRGB(15) == dark.projectIconRGB(15))
  }

  /// A fade nobody can read through is not a signal, so the value is
  /// clamped rather than taken at its word.
  @Test func aFadeOutsideTheUsableRangeIsClampedAndOneOfTheWrongTypeIsTheBases() throws {
    func opacity(_ value: String) throws -> Double {
      try theme(#""terminal": { "inactive_pane_opacity": \#(value) }"#).inactivePaneOpacity
    }
    #expect(try opacity("0") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("-4") == Theme.minimumInactivePaneOpacity)
    #expect(try opacity("2") == 1)
    #expect(try opacity("0.6") == 0.6)
    #expect(try opacity(#""half""#) == dark.inactivePaneOpacity)
  }

  private func theme(_ keys: String) throws -> Theme {
    try decodeJSON(Theme.self, #"{ "id": "x", "name": "X"\#(keys.isEmpty ? "" : ", " + keys) }"#)
  }
}
