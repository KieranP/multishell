/// The key a shortcut presses: a character as the keyboard layout types it
/// unshifted, lowercase, or a key that types none.
public enum ShortcutKey: Hashable, Sendable {
  case backspace
  case character(Character)
  case downArrow
  case end
  case forwardDelete
  /// F1 to F20, by number.
  case function(Int)
  case home
  case leftArrow
  case pageDown
  case pageUp
  case returnKey
  case rightArrow
  case space
  case tab
  case upArrow

  /// AppKit's function keys run to F35; past F20 no Mac keyboard has one.
  public static let functionNumbers = 1...20

  public static var namedKeys: [Self] { named.map(\.key) }

  /// Each key without a character, with its word in the state file and its
  /// glyph. The words are `ControlKey`'s where it names the same key.
  static let named: [(key: Self, word: String, glyph: String)] = [
    (.tab, "tab", "⇥"), (.returnKey, "enter", "↩"), (.space, "space", "Space"),
    (.backspace, "backspace", "⌫"), (.forwardDelete, "delete", "⌦"), (.home, "home", "↖"),
    (.end, "end", "↘"), (.pageUp, "pageup", "⇞"), (.pageDown, "pagedown", "⇟"),
    (.leftArrow, "left", "←"), (.rightArrow, "right", "→"), (.upArrow, "up", "↑"),
    (.downArrow, "down", "↓"),
  ]
}
