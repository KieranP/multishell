/// A key and the modifiers held with it, as a menu item's key equivalent
/// matches it. It names no engine; the app spells it for the terminal's.
public struct KeyCombination: Hashable, Sendable {
  public let key: ShortcutKey
  public let modifiers: ShortcutModifiers

  /// A character is kept lowercase, Shift being a modifier of its own.
  public init(_ key: ShortcutKey, _ modifiers: ShortcutModifiers = []) {
    if case .character(let character) = key, let lower = character.lowercased().first {
      self.key = .character(lower)
    } else {
      self.key = key
    }
    self.modifiers = modifiers
  }

  /// Command and a character, with any other modifiers, as most defaults are.
  static func command(_ character: Character, _ extra: ShortcutModifiers = []) -> Self {
    Self(.character(character), extra.union(.command))
  }
}
