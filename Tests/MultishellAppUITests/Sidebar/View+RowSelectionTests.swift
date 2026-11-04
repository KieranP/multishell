import Testing

@testable import MultishellCore

@Suite
struct ViewRowSelectionTests {
  /// Multishell Light's 18% wash, the faintest the sidebar was judged to need.
  private static let faintestReadableWash = 1.25

  @Test func everyBuiltInThemesSelectedRowStandsOffItsSidebarWithNoOutline() {
    for theme in Theme.builtins {
      let panel = theme.interfaceRGB(.background, in: .projectsPanel)
      let wash = theme.interfaceRGB(.selectionBackground, in: .projectsPanel)
      let ratio = wash.composited(over: panel).contrast(with: panel)
      #expect(ratio >= Self.faintestReadableWash, "\(theme.name): \(ratio)")
    }
  }
}
