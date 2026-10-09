import SwiftUI

/// A keyboard shortcut the app owns, in SwiftUI's spelling and Ghostty's,
/// declared once: a combination nobody unbound is dead in a Ghostty pane.
struct AppShortcut {
  let key: KeyEquivalent
  let modifiers: EventModifiers
  /// Whether the surface keeps its own binding rather than giving it up to
  /// the menu bar. True only where Ghostty's action is what a pane wants.
  let surfaceKeepsBinding: Bool

  init(_ key: KeyEquivalent, _ extra: EventModifiers = [], surfaceKeepsBinding: Bool = false) {
    self.key = key
    self.modifiers = extra.union(.command)
    self.surfaceKeepsBinding = surfaceKeepsBinding
  }

  private init(key: KeyEquivalent, modifiers: EventModifiers, surfaceKeepsBinding: Bool) {
    self.key = key
    self.modifiers = modifiers
    self.surfaceKeepsBinding = surfaceKeepsBinding
  }

  /// Control-only, for the tab cycling that does not take Command.
  static func control(_ key: KeyEquivalent, _ extra: EventModifiers = []) -> Self {
    Self(key: key, modifiers: extra.union(.control), surfaceKeepsBinding: false)
  }
}
