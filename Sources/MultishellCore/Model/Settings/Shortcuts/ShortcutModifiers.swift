/// The modifier keys held for a shortcut.
public struct ShortcutModifiers: OptionSet, Hashable, Sendable {
  public static let control = Self(rawValue: 1 << 0)
  public static let option = Self(rawValue: 1 << 1)
  public static let shift = Self(rawValue: 1 << 2)
  public static let command = Self(rawValue: 1 << 3)

  /// Each modifier with its glyph and its word in the state file, in the order
  /// a menu draws them, ⌃⌥⇧⌘.
  static let menuOrder: [(modifier: Self, glyph: Character, word: String)] = [
    (.control, "⌃", "ctrl"), (.option, "⌥", "alt"), (.shift, "⇧", "shift"), (.command, "⌘", "cmd"),
  ]

  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}
