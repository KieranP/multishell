import SwiftUI

extension AppShortcut {
  /// The same combination as Ghostty spells it, in the modifier order its
  /// own docs use, so this stays diffable against a config.
  var ghosttyCombo: String {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("super") }
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    parts.append(Self.ghosttyName(of: key))
    return parts.joined(separator: "+")
  }

  /// Ghostty names a few keys rather than taking their character. The arrows
  /// arrive as the private-use scalars AppKit gives them.
  private static func ghosttyName(of key: KeyEquivalent) -> String {
    switch key.character {
    case "\t": "tab"
    case "\r": "enter"
    case ",": "comma"
    case KeyEquivalent.leftArrow.character: "left"
    case KeyEquivalent.rightArrow.character: "right"
    case KeyEquivalent.upArrow.character: "up"
    case KeyEquivalent.downArrow.character: "down"
    default: String(key.character)
    }
  }
}
