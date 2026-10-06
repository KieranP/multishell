import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct GhosttyAppLayerTests {
  /// libghostty drops a line it refuses without a word, which here would be a
  /// search colour or an unbind gone: every built-in theme.
  @Test func everyBuiltInThemeSetsReadableSearchColoursInAConfigurationLibghosttyAccepts() throws {
    for theme in Theme.builtins {
      let rendered = GhosttyAppLayer.configuration(theme, Appearance()).rendered
      #expect(rendered.contains("search-background = #"), "\(theme.name)")
      #expect(rendered.contains("search-selected-background = #"), "\(theme.name)")
      // Match text is the dark one of the pair: a light theme's background is
      // near white, and white on yellow cannot be read.
      let text = (theme.isDark ? theme.backgroundRGB : theme.foregroundRGB).hex
      #expect(rendered.contains("search-foreground = \(text)"), "\(theme.name)")
      #expect(rendered.contains("search-selected-foreground = \(text)"), "\(theme.name)")
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
}
