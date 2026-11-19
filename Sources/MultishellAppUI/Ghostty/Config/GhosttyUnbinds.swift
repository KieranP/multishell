import MultishellCore

/// What the terminal surface is told to unbind: shortcuts it would eat before
/// the menu bar or the system sees them, and plain keys the program needs.
enum GhosttyUnbinds {
  /// Ghostty bindings on plain keys, released so the key reaches the program:
  /// its performable `esc=end_search` ate Escape under our bar; terminals/find.md.
  static let surfaceReleases = ["escape"]

  /// The menus' keys, then every reserved combination, which no command of
  /// ours carries and the surface must still give up, then the releases.
  static func all(unbinding keys: [KeyCombination]) -> [String] {
    let reserved = ReservedShortcut.allCases.map(\.combination)
    return (keys + reserved).flatMap(\.ghosttyTriggers).uniqued(by: \.self) + surfaceReleases
  }
}
