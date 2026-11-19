import MultishellCore
import SwiftUI

extension KeyCombination {
  /// A changed command's keys were typed on this layout, so SwiftUI must not
  /// move them to where its US equivalent sits on another.
  func keyboardShortcut(isChanged: Bool) -> KeyboardShortcut {
    KeyboardShortcut(
      KeyEquivalent(menuKeyCharacter),
      modifiers: modifiers.eventModifiers,
      localization: isChanged ? .custom : .automatic,
    )
  }
}
