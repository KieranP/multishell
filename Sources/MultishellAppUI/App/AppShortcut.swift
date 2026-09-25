import SwiftUI

/// A keyboard shortcut the app owns, in SwiftUI's spelling and Ghostty's,
/// declared once: a combination nobody unbound is dead in a Ghostty pane.
struct AppShortcut {
  let key: KeyEquivalent
  let modifiers: EventModifiers
  /// Whether the surface keeps its own binding rather than giving it up to
  /// the menu bar. True only where Ghostty's action is what a pane wants.
  let surfaceKeeps: Bool

  init(_ key: KeyEquivalent, _ extra: EventModifiers = [], surfaceKeeps: Bool = false) {
    self.key = key
    self.modifiers = extra.union(.command)
    self.surfaceKeeps = surfaceKeeps
  }

  /// Control-only, for the tab cycling that does not take Command.
  static func control(_ key: KeyEquivalent, _ extra: EventModifiers = []) -> AppShortcut {
    AppShortcut(key: key, modifiers: extra.union(.control), surfaceKeeps: false)
  }

  private init(key: KeyEquivalent, modifiers: EventModifiers, surfaceKeeps: Bool) {
    self.key = key
    self.modifiers = modifiers
    self.surfaceKeeps = surfaceKeeps
  }

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

extension View {
  /// Attaches both halves of a shortcut's contract: the menu item's
  /// equivalent here, and the surface's unbind through `AppShortcuts`.
  func keyboardShortcut(_ shortcut: AppShortcut) -> some View {
    keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
  }
}
