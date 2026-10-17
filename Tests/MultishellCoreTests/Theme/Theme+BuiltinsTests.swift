import Testing

@testable import MultishellCore

@Suite
struct ThemeBuiltinsTests {
  @Test func eachBuiltInThemeSetsEveryKeyEverySectionTakes() {
    for theme in Theme.builtins {
      #expect(Set(theme.terminalColors.keys) == Set(TerminalColorKey.allCases), "\(theme.id)")
      #expect(theme.ansiColors.count == Theme.ansiSlotCount, "\(theme.id)")
      #expect(theme.ownInactivePaneOpacity != nil, "\(theme.id)")
      #expect(Set(theme.fileColors.keys) == Set(FileColorKey.allCases), "\(theme.id)")
      for section in InterfaceSection.allCases {
        #expect(
          Set(theme.interfaceColors[section]?.keys ?? [:].keys) == Set(section.colorKeys),
          "\(theme.id) \(section)",
        )
      }
      #expect(theme.projectIconColors.count == Theme.ansiSlotCount, "\(theme.id)")
      let agents = AgentCatalogue.agents.map(\.id) + [AgentCatalogue.customID]
      #expect(Set(theme.agentMarkColors.keys) == Set(agents), "\(theme.id)")
    }
  }

  @Test func everyBuiltInColourParsesOrIsAnEmptyThatMeansNone() {
    for theme in Theme.builtins {
      let colors =
        theme.terminalColors.map { ($0.key.takesNone, $0.value) }
        + theme.ansiColors.values.map { (false, $0) }
        + theme.fileColors.values.map { (false, $0) }
        + theme.interfaceColors.values.flatMap(\.values).map { (false, $0) }
        + theme.projectIconColors.values.map { (false, $0) }
        + theme.agentMarkColors.values.map { (true, $0) }
      for (takesNone, text) in colors {
        #expect(HexColor.parse(text) != nil || (takesNone && text.isEmpty), "\(theme.id): \(text)")
      }
    }
  }

  @Test func eachBaseThemeIsTheDarknessItsNameSays() {
    #expect(Theme.multishellDark.isDark && !Theme.multishellLight.isDark)
  }

  @Test func eachBuiltInRingsInItsOwnColourAndFadesItsOtherPanesBySome() {
    for theme in Theme.builtins {
      #expect(theme.terminalRGB(.focusRing) != nil, "\(theme.id) draws no focus ring")
      #expect(
        theme.terminalRGB(.focusRing) != theme.terminalRGB(.selectionBackground),
        "\(theme.id) rings in its selection colour, which is mixed to sit under text",
      )
      #expect(
        theme.inactivePaneOpacity > Theme.minimumInactivePaneOpacity
          && theme.inactivePaneOpacity < 1,
        "\(theme.id) fades unfocused panes by nothing, or by all",
      )
    }
  }

  @Test func tenEditorThemesShipAfterTheTwoBaseOnes() {
    #expect(
      Theme.builtins.map(\.id) == [
        "multishell.dark", "multishell.light", "dracula", "one-dark", "nord", "solarized-light",
        "github-dark-default", "github-light-default", "catppuccin-mocha",
        "catppuccin-macchiato", "catppuccin-frappe", "catppuccin-latte",
      ]
    )
  }
}
