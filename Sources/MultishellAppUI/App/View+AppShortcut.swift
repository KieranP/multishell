import SwiftUI

extension View {
  /// Attaches both halves of a shortcut's contract: the menu item's
  /// equivalent here, and the surface's unbind through `AppShortcuts`.
  func keyboardShortcut(_ shortcut: AppShortcut) -> some View {
    keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
  }
}
