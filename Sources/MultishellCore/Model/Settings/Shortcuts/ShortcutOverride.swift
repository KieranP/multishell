/// What the user chose for a command in place of its default: other keys, or
/// none, its menu item staying.
public enum ShortcutOverride: Hashable, Sendable {
  case keys(KeyCombination)
  case noKeys
}
