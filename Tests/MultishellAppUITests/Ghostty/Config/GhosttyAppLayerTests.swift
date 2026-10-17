import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct GhosttyAppLayerTests {
  /// libghostty drops a line it refuses without a word, which here would be a
  /// search colour or an unbind gone. Readable is WCAG's 3:1 for large text.
  @Test func everyBuiltInThemeSetsReadableSearchColoursInAConfigurationLibghosttyAccepts() throws {
    for theme in Theme.builtins {
      let rendered = GhosttyAppLayer.configuration(theme, Appearance()).rendered
      #expect(rendered.contains("search-background = #"), "\(theme.name)")
      #expect(rendered.contains("search-selected-background = #"), "\(theme.name)")
      #expect(rendered.contains("search-foreground = #"), "\(theme.name)")
      #expect(rendered.contains("search-selected-foreground = #"), "\(theme.name)")
      for (text, background) in [
        (TerminalColorKey.searchForeground, TerminalColorKey.searchBackground),
        (.searchSelectedForeground, .searchSelectedBackground),
      ] {
        let ratio = try contrast(
          #require(theme.terminalRGB(text)),
          #require(theme.terminalRGB(background)),
        )
        #expect(ratio >= 3, "\(theme.name) \(text): \(ratio)")
      }
      let diagnostics = try libghosttyDiagnostics(rendered)
      #expect(diagnostics.isEmpty, "\(theme.name): \(diagnostics)")
    }
  }

  /// `font-family` is a list in Ghostty; appended to a user's, ours was only a fallback.
  @Test func theFontChosenInSettingsEmptiesTheFontListBeforeNamingItself() throws {
    let appearance = Appearance(terminalFontName: "Menlo")
    let rendered = GhosttyAppLayer.configuration(Theme.builtins[0], appearance).rendered
    let cleared = try #require(rendered.range(of: "font-family = \"\"\n"))
    let ours = try #require(rendered.range(of: "font-family = Menlo"))
    #expect(cleared.upperBound <= ours.lowerBound)
    let diagnostics = try libghosttyDiagnostics(rendered)
    #expect(diagnostics.isEmpty, "\(diagnostics)")
  }

  @Test func theAppLayerTurnsTheEnginesShellIntegrationOff() {
    let rendered = GhosttyAppLayer.configuration(Theme.builtins[0], Appearance()).rendered
    #expect(rendered.contains("shell-integration = none"))
  }

  @Test func everyTerminalColourReachesLibghosttyOpaqueAndAnEmptyOneIsLeftToIt() throws {
    let theme = try JSONDecoder().decode(
      Theme.self,
      from: Data(
        ##"""
        { "id": "x", "name": "X", "terminal": {
          "background": "#10203080", "cursor_text": "#a0f0c0", "selection_foreground": "",
          "search_selected_foreground": "#a0f0c0" } }
        """##.utf8
      ),
    )
    let rendered = GhosttyAppLayer.configuration(theme, Appearance()).rendered
    #expect(rendered.contains("background = #102030\n"))
    #expect(rendered.contains("cursor-text = #a0f0c0"))
    #expect(rendered.contains("search-selected-foreground = #a0f0c0"))
    #expect(!rendered.contains("selection-foreground"))
    let diagnostics = try libghosttyDiagnostics(rendered)
    #expect(diagnostics.isEmpty, "\(diagnostics)")
  }

  private func contrast(_ first: RGB, _ second: RGB) -> Double {
    func luminance(_ colour: RGB) -> Double {
      func channel(_ value: UInt8) -> Double {
        let linear = Double(value) / 255
        return linear <= 0.03928 ? linear / 12.92 : pow((linear + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * channel(colour.red) + 0.7152 * channel(colour.green)
        + 0.0722 * channel(colour.blue)
    }
    let luminances = [luminance(first), luminance(second)]
    return (luminances.max()! + 0.05) / (luminances.min()! + 0.05)
  }
}
