import MultishellCore

/// The layer the app hands libghostty on top of the user's files: the theme,
/// the font, the keybinds it unbinds and the integration it leaves to ours.
enum GhosttyAppLayer {
  static func configuration(_ theme: Theme, _ appearance: Appearance) -> GhosttyConfigText {
    GhosttyConfigText { config in
      config.set("background", theme.background)
      config.set("foreground", theme.foreground)
      config.set("cursor-color", theme.cursor)
      config.set("selection-background", theme.selectionBackground)
      for (index, paletteColor) in theme.ansi.enumerated() {
        config.set("palette", "\(index)=\(paletteColor)")
      }
      // Find's matches in the theme's yellow, the selected one in the ring's
      // colour, their text the darker of the theme's pair; see appearance.md.
      let selected = theme.focusRingRGB ?? theme.selectionBackgroundRGB
      let text = theme.isDark ? theme.backgroundRGB : theme.foregroundRGB
      config.set("search-background", theme.ansiRGB(.yellow).hex)
      config.set("search-foreground", text.hex)
      config.set("search-selected-background", selected.hex)
      config.set("search-selected-foreground", text.hex)
      if let name = appearance.terminalFontName {
        // A list in Ghostty: emptied first, or ours trails the user's as a fallback.
        config.set("font-family", "\"\"")
        config.set("font-family", name)
      }
      config.set("font-size", appearance.terminalFontSize)
      // Our hooks write the marks, and zsh's the title and cursor, so the
      // engine injects nothing of its own into a shell; see terminals.md.
      config.set("shell-integration", "none")

      // Ghostty's defaults bind our shortcuts to actions this embedding
      // cannot perform, so unbind exactly those.
      for combo in GhosttyUnbinds.all {
        config.set("keybind", "\(combo)=unbind")
      }
    }
  }
}
