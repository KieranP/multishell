import Testing

@testable import MultishellCore

@Suite
struct ViewRowSelectionTests {
  @Test func everyBuiltInThemesSelectedRowStandsOffItsSidebarWithNoOutline() {
    for theme in Theme.builtins {
      let panel = theme.interfaceRGB(.background, in: .projectsPanel)
      let wash = theme.interfaceRGB(.selectionBackground, in: .projectsPanel)
      let ratio = wash.composited(over: panel).contrast(with: panel)
      #expect(ratio >= ContrastFloor.faintestSelection, "\(theme.name): \(ratio)")
    }
  }
}
