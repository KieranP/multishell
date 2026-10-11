import AppKit

extension NSEvent {
  /// This key event with other text or modifiers. The timestamp is kept, as
  /// `GhosttyKeyEquivalent` knows a key's second offer by it.
  func keyCopy(
    characters: String,
    charactersIgnoringModifiers: String,
    modifierFlags: NSEvent.ModifierFlags? = nil,
  ) -> NSEvent? {
    Self.keyEvent(
      with: type,
      location: locationInWindow,
      modifierFlags: modifierFlags ?? self.modifierFlags,
      timestamp: timestamp,
      windowNumber: windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers,
      isARepeat: isARepeat,
      keyCode: keyCode,
    )
  }

  /// This key event with `flags`, its characters as the layout gives them
  /// there; itself where unchanged, as Korean input breaks on a copy.
  func translated(to flags: NSEvent.ModifierFlags) -> NSEvent {
    guard flags != modifierFlags else { return self }
    return keyCopy(
      characters: characters(byApplyingModifiers: flags) ?? "",
      charactersIgnoringModifiers: charactersIgnoringModifiers ?? "",
      modifierFlags: flags,
    ) ?? self
  }
}
