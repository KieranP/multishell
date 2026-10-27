import AppKit

/// A menu item's keys as the menu draws them, `⌥⌘G`, for the quick switcher's
/// command rows and `multishell ui menu`.
enum MenuShortcutText {
  /// The keys AppKit stores as a private-use character or a control code.
  private static let namedKeys: [Character: String] = [
    "\u{F700}": "↑", "\u{F701}": "↓", "\u{F702}": "←", "\u{F703}": "→",
    "\u{F728}": "⌦", "\u{F729}": "↖", "\u{F72B}": "↘", "\u{F72C}": "⇞", "\u{F72D}": "⇟",
    "\t": "⇥", "\r": "↩", "\u{3}": "⌤", "\u{1b}": "⎋", "\u{8}": "⌫", "\u{7f}": "⌫", " ": "␣",
  ]
  /// AppKit's F1 to F35, which run on from this private-use character.
  private static let firstFunctionKey = 0xF704
  private static let functionKeyCount = 35

  /// `nil` for an item without a key, or with one there is no glyph for.
  static func of(_ item: NSMenuItem) -> String? {
    guard let key = item.keyEquivalent.first, let keyName = name(of: key) else { return nil }
    let flags = item.keyEquivalentModifierMask
    // Only a system item keeps fn, Emoji & Symbols' fn E; AppKit refuses it on ours.
    var text = flags.contains(.function) ? "fn" : ""
    if flags.contains(.control) { text += "⌃" }
    if flags.contains(.option) { text += "⌥" }
    if flags.contains(.shift) || key.isUppercase { text += "⇧" }
    if flags.contains(.command) { text += "⌘" }
    return text + keyName
  }

  /// A control code or one of AppKit's private-use keys left unnamed has no
  /// glyph of its own, and would print as an empty box.
  private static func name(of key: Character) -> String? {
    if let named = namedKeys[key] { return named }
    guard let scalar = key.unicodeScalars.first else { return nil }
    let number = Int(scalar.value) - firstFunctionKey + 1
    if (1...functionKeyCount).contains(number) { return "F\(number)" }
    if scalar.properties.generalCategory == .control
      || scalar.properties.generalCategory == .privateUse
    {
      return nil
    }
    return key.uppercased()
  }
}
