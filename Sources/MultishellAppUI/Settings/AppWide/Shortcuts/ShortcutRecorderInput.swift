import AppKit
import MultishellCore

/// What a key press means to a Shortcuts or Actions row that is recording.
enum ShortcutRecorderInput: Equatable {
  case cancel
  /// Delete with no modifier pressed: no keys, a command keeping its menu item.
  case clear
  /// A key no shortcut can be: keypad Enter, Help, F21 and up, or a dead key.
  case ignored
  case keys(KeyCombination)

  /// The keys that type no character, by what the menus store them as, Delete
  /// also arriving as 0x7F.
  private static let namedKeysByCharacter: [Int: ShortcutKey] = {
    var keys: [Int: ShortcutKey] = [0x7F: .backspace]
    for key in ShortcutKey.namedKeys {
      guard let scalar = KeyCombination(key).menuKeyCharacter.unicodeScalars.first else { continue }
      keys[Int(scalar.value)] = key
    }
    return keys
  }()
  private static let escape = 0x1B

  /// The key comes as the layout types it with no modifier pressed, as a menu's key
  /// equivalent matches it, so ⇧⌘[ is `[` with Shift, not `{`.
  init(_ event: NSEvent) {
    guard event.type == .keyDown, let scalar = Self.unshiftedKey(of: event) else {
      self = .ignored
      return
    }
    let modifiers = ShortcutModifiers(event.modifierFlags)
    let value = Int(scalar.value)
    if value == Self.escape {
      self = .cancel
    } else if let named = Self.namedKeysByCharacter[value] {
      self =
        named == .backspace && modifiers.isEmpty ? .clear : .keys(KeyCombination(named, modifiers))
    } else if let number = Self.functionNumber(value) {
      self = .keys(KeyCombination(.function(number), modifiers))
    } else if KeyCombination.isTypable(Character(scalar)) {
      self = .keys(KeyCombination(.character(Character(scalar)), modifiers))
    } else {
      self = .ignored
    }
  }

  /// The layout's translation gives an F-key or an arrow as a control code;
  /// AppKit's own character for it is the private-use one the menus use.
  private static func unshiftedKey(of event: NSEvent) -> UnicodeScalar? {
    if let named = event.charactersIgnoringModifiers?.unicodeScalars.first,
      named.properties.generalCategory == .privateUse
    {
      return named
    }
    return event.characters(byApplyingModifiers: [])?.unicodeScalars.first
  }

  private static func functionNumber(_ value: Int) -> Int? {
    let number = value - NSF1FunctionKey + 1
    return ShortcutKey.functionNumbers.contains(number) ? number : nil
  }
}
