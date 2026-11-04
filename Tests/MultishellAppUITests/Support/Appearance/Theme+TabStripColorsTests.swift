import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
struct ThemeTabStripColorsTests {
  @Test func everyBuiltInThemesHoverWashStandsOffTheStripTheShownTabAndTheXOnIt() throws {
    for theme in Theme.builtins {
      let strip = theme.interfaceRGB(.background, in: .tabBar)
      let shown = theme.interfaceRGB(.background, in: .terminalTab)
      let fill = try #require(theme.hoverWashRGB(onShownTab: false, isHovered: true))
      let wash = fill.composited(over: strip)
      let litX = fill.composited(over: wash)
      #expect(
        wash.contrast(with: strip) >= ContrastFloor.faintestReadable,
        "\(theme.name) on its strip",
      )
      #expect(
        wash.contrast(with: shown) >= ContrastFloor.faintestReadable,
        "\(theme.name) beside its shown tab",
      )
      #expect(
        litX.contrast(with: wash) >= ContrastFloor.faintestReadable,
        "\(theme.name) under its X",
      )
      for section in [InterfaceSection.terminalTab, .fileTab] {
        let ground = theme.interfaceRGB(.background, in: section)
        let litShownX = fill.composited(over: ground)
        #expect(
          litShownX.contrast(with: ground) >= ContrastFloor.faintestReadable,
          "\(theme.name) under a shown \(section)'s X",
        )
      }
    }
  }
}
