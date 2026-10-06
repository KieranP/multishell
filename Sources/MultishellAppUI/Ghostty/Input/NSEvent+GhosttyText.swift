import AppKit

extension NSEvent {
  /// The text a key types, after Ghostty's `ghosttyCharacters`: control lifted
  /// off a control character, libghostty encoding it, and none for a function key.
  var ghosttyText: String? {
    guard let characters else { return nil }
    guard characters.count == 1, let scalar = characters.unicodeScalars.first else {
      return characters
    }
    if scalar.value < 0x20 {
      return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
    }
    // AppKit spells a function key as one scalar in this private-use range.
    return (0xF700...0xF8FF).contains(scalar.value) ? nil : characters
  }
}
