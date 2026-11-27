import AppKit
import MultishellCore

extension NSMenuItem {
  /// `nil` takes the item's keys away. Keys the user typed were typed on this
  /// layout, so AppKit must not move them to their US place on another.
  func setKeys(_ keys: KeyCombination?, isChanged: Bool) {
    keyEquivalent = keys.map { String($0.menuKeyCharacter) } ?? ""
    keyEquivalentModifierMask = keys?.modifiers.modifierFlags ?? []
    allowsAutomaticKeyEquivalentLocalization = !isChanged
  }
}
