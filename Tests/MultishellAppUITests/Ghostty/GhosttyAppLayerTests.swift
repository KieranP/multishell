import GhosttyTerminal
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct GhosttyAppLayerTests {
  /// One line libghostty cannot parse refuses the whole config. The app layer
  /// carries the unbinds and the four search colours: every built-in theme.
  @MainActor
  @Test func everyBuiltInThemesConfigurationIsOneThePinnedLibghosttyAccepts() {
    for theme in Theme.builtins {
      let rendered = GhosttyAppLayer.configuration(theme, Appearance()).rendered
      #expect(rendered.contains("search-background = #"), "\(theme.name)")
      #expect(rendered.contains("search-selected-background = #"), "\(theme.name)")
      // Match text is the dark one of the pair: a light theme's background is
      // near white, and white on yellow cannot be read.
      let text = (theme.isDark ? theme.backgroundRGB : theme.foregroundRGB).hex
      #expect(rendered.contains("search-foreground = \(text)"), "\(theme.name)")
      #expect(rendered.contains("search-selected-foreground = \(text)"), "\(theme.name)")
      let controller = TerminalController(configSource: .generated(rendered))
      #expect(
        controller.lastConfigurationIssue == nil,
        "\(theme.name): \(controller.lastConfigurationIssue ?? "")")
    }
  }
}
