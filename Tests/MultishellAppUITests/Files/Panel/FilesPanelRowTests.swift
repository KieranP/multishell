import Testing

@testable import MultishellCore

@Suite
struct FilesPanelRowTests {
  @Test func everyBuiltInThemesFileInFrontStandsOffThePanelAsTheSidebarsSelectionDoes() {
    for theme in Theme.builtins {
      let panel = theme.interfaceRGB(.background, in: .filesPanel)
      let wash = theme.interfaceRGB(.selectionBackground, in: .filesPanel)
      let ratio = wash.composited(over: panel).contrast(with: panel)
      #expect(ratio >= ContrastFloor.faintestSelection, "\(theme.name): \(ratio)")
    }
  }
}
