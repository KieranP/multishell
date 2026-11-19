import MultishellCore

/// The layer the app hands libghostty on top of the user's files: the theme,
/// the font, the keybinds it unbinds and the integration it leaves to ours.
enum GhosttyAppLayer {
  static func configuration(
    _ theme: Theme,
    _ appearance: Appearance,
    unbinding keys: [KeyCombination],
  ) -> GhosttyConfigText {
    GhosttyConfigText { config in
      // libghostty takes no alpha, and drops a line it refuses without a word.
      func set(_ name: String, _ key: TerminalColorKey) {
        if let color = theme.terminalRGB(key) { config.set(name, color.opaqueHex) }
      }
      set("background", .background)
      set("foreground", .foreground)
      set("cursor-color", .cursor)
      set("cursor-text", .cursorText)
      set("selection-background", .selectionBackground)
      set("selection-foreground", .selectionForeground)
      for slot in 0..<Theme.ansiSlotCount {
        config.set("palette", "\(slot)=\(theme.ansiRGB(slot).opaqueHex)")
      }
      set("search-background", .searchBackground)
      set("search-foreground", .searchForeground)
      set("search-selected-background", .searchSelectedBackground)
      set("search-selected-foreground", .searchSelectedForeground)
      if let name = appearance.terminalFontName {
        // A list in Ghostty: emptied first, or ours trails the user's as a fallback.
        config.set("font-family", "\"\"")
        config.set("font-family", name)
      }
      config.set("font-size", appearance.terminalFontSize)
      // Our hooks write the marks, zsh's the title and cursor, and fish 4 writes both itself, so
      // the engine injects nothing into a shell; see terminals/shell-integration.md.
      config.set("shell-integration", "none")

      // The menus' keys and the reserved ones, so the surface takes none before
      // the menu bar or the system; Docs/design/shortcuts.md.
      for combo in GhosttyUnbinds.all(unbinding: keys) {
        config.set("keybind", "\(combo)=unbind")
      }
    }
  }
}
