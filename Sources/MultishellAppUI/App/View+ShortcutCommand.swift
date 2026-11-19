import MultishellAppCore
import MultishellCore
import SwiftUI

extension View {
  /// The command's keys in force, none where it has none. The engine's unbind
  /// is the other half, `AppModel.surfaceUnbinds`.
  func keyboardShortcut(_ command: ShortcutCommand, in model: AppModel) -> some View {
    let shortcut = model.menuShortcut(for: command)
    return keyboardShortcut(shortcut.keys?.keyboardShortcut(isChanged: shortcut.isChanged))
  }
}
