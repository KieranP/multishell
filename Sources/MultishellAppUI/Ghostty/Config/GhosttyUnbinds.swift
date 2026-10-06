/// What the terminal surface is told to unbind, or it eats these before
/// the menu bar sees them.
enum GhosttyUnbinds {
  /// Hides the Dock. Listed so nothing here claims it, and so the reason Move
  /// Tab to New Group is not on it stays written down.
  private static let dockToggle = "super+alt+d"

  /// Combinations the system owns over one of our windows. No menu item of
  /// ours carries these, and the surface must still give them up.
  static let systemOwned = [
    "super+shift+n", "super+comma", "super+q", "super+ctrl+f", "super+enter", dockToggle,
  ]

  /// Ghostty bindings on plain keys, released so the key reaches the program:
  /// its performable `esc=end_search` ate Escape under our bar; terminals.md.
  static let surfaceReleases = ["escape"]

  static let all: [String] =
    AppShortcutCatalogue.all.filter { !$0.surfaceKeeps }.map(\.ghosttyCombo) + systemOwned
    + surfaceReleases
}
