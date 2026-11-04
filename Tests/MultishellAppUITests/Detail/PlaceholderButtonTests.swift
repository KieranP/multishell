import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct PlaceholderButtonTests {
  @Test func everyBuiltInThemesPlaceholderButtonsEdgeStandsOffItsGroundAndItsBlock() {
    for theme in Theme.builtins {
      let ground = theme.interfaceRGB(.background, in: .detail)
      let block = theme.interfaceRGB(.blockBackground, in: .detail).composited(over: ground)
      let edge = theme.interfaceRGB(.border, in: .detail).composited(over: block)
      #expect(
        edge.contrast(with: ground) >= ContrastFloor.faintestReadable,
        "\(theme.name) on its ground",
      )
      #expect(
        edge.contrast(with: block) >= ContrastFloor.faintestReadable,
        "\(theme.name) on its block",
      )
    }
  }
}
