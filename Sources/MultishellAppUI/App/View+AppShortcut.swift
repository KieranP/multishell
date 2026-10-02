import SwiftUI

extension View {
  /// The menu item's key equivalent. The surface's unbind is the other half,
  /// and comes from the shortcut's place in `AppShortcutCatalogue.all`.
  func keyboardShortcut(_ shortcut: AppShortcut) -> some View {
    keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
  }
}
