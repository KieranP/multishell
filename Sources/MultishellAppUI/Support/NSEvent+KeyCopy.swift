import AppKit

extension NSEvent {
  /// This key event with other text or modifiers. The timestamp is kept, as
  /// `GhosttyKeyEquivalent` knows a key's second offer by it.
  func keyCopy(
    modifierFlags: NSEvent.ModifierFlags? = nil, characters: String,
    charactersIgnoringModifiers: String
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: type, location: locationInWindow, modifierFlags: modifierFlags ?? self.modifierFlags,
      timestamp: timestamp, windowNumber: windowNumber, context: nil, characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers, isARepeat: isARepeat,
      keyCode: keyCode)
  }
}
