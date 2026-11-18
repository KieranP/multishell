import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ChipOnFillTests {
  private static func theme(_ name: String) throws -> Theme {
    try #require(Theme.builtins.first { $0.name == name })
  }

  @Test func aTranslucentFillIsDrawnAgainToStackAShadeUp() throws {
    let theme = try Self.theme("Multishell Dark")

    #expect(ChipOnFill.colorKey(in: .fileTab, of: theme) == .fill)
  }

  @Test func anOpaqueFillGivesWayToTheSelectionSinceDrawnTwiceItReadsAsNone() throws {
    let theme = try Self.theme("Catppuccin Mocha")

    #expect(ChipOnFill.colorKey(in: .fileTab, of: theme) == .selectionBackground)
  }

  @Test func everyBuiltinThemesChipDiffersFromTheFillUnderIt() {
    for theme in Theme.builtins {
      let key = ChipOnFill.colorKey(in: .fileTab, of: theme)
      let chip = theme.interfaceRGB(key, in: .fileTab)
      let fill = theme.interfaceRGB(.fill, in: .fileTab)
      #expect(key == .fill ? fill.opacity < 1 : chip != fill, "\(theme.name)")
    }
  }
}
