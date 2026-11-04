import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct GlyphHoverModifierTests {
  private static let litAreas: [InterfaceSection] = [
    .projectsPanel, .header, .fileTab, .findBar, .tabBar,
  ]

  @Test func everyBuiltInThemesLitSquareStandsOffEachAreaItLightsIn() {
    for theme in Theme.builtins {
      for area in Self.litAreas {
        let ground = theme.interfaceRGB(.background, in: area)
        let square = theme.interfaceRGB(.fill, in: area).composited(over: ground)
        let ratio = square.contrast(with: ground)
        #expect(ratio >= ContrastFloor.faintestReadable, "\(theme.name) \(area): \(ratio)")
      }
    }
  }
}
