import GhosttyTerminal
import MultishellCore

/// The layer the app hands libghostty on top of the user's files: the theme,
/// the font and the keybinds it unbinds.
@MainActor
enum GhosttyThemeConfig {
  static func configuration(
    _ theme: Theme, _ appearance: Appearance
  ) -> TerminalConfiguration {
    TerminalConfiguration { builder in
      builder.withBackground(theme.background)
      builder.withForeground(theme.foreground)
      builder.withCursorColor(theme.cursor)
      builder.withSelectionBackground(theme.selectionBackground)
      for (index, colour) in theme.ansi.enumerated() {
        builder.withPalette(index, color: colour)
      }
      // Find's matches in the theme's yellow, the selected one in the ring's
      // colour, their text the darker of the theme's pair; see appearance.md.
      let selected = theme.focusRingRGB ?? theme.selectionRGB
      let text = theme.isDark ? theme.backgroundRGB : theme.foregroundRGB
      builder.withCustom("search-background", theme.ansiRGB(3).hex)
      builder.withCustom("search-foreground", text.hex)
      builder.withCustom("search-selected-background", selected.hex)
      builder.withCustom("search-selected-foreground", text.hex)
      if let name = appearance.fontName {
        builder.withFontFamily(name)
      }
      builder.withFontSize(Float(appearance.fontSize))

      // Ghostty's defaults bind our shortcuts to actions this embedding
      // cannot perform, so unbind exactly those, from `AppShortcuts`.
      for combo in AppShortcuts.unbound {
        builder.withCustom("keybind", "\(combo)=unbind")
      }
    }
  }
}
