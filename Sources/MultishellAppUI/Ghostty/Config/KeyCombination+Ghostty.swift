import MultishellCore

extension KeyCombination {
  /// Ghostty's W3C names for punctuation. A name binds the physical key and a
  /// character the one typed; its defaults use both, so both are unbound.
  private static let ghosttyPunctuationNames: [Character: String] = [
    "`": "backquote", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right",
    "\\": "backslash", ";": "semicolon", "'": "quote", ",": "comma", ".": "period", "/": "slash",
  ]

  /// Ghostty reads it as the step between a sequence's keys, so no trigger
  /// names that key; nothing Ghostty binds by default is on it.
  private static let sequenceStep: Character = ">"

  /// Each keybind trigger Ghostty could hold the combination under, in its docs'
  /// modifier order; Docs/design/shortcuts.md says why punctuation has two.
  var ghosttyTriggers: [String] {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("super") }
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    let prefix = parts.map { $0 + "+" }.joined()
    return Self.ghosttyKeyNames(of: key).map { prefix + $0 }
  }

  /// The physical key's name, which a binding may use in place of the character.
  private static func w3cName(of character: Character) -> String? {
    if let punctuation = ghosttyPunctuationNames[character] { return punctuation }
    guard character.isASCII else { return nil }
    if character.isNumber { return "digit_\(character)" }
    return character.isLetter ? "key_\(character)" : nil
  }

  // One case a key, exhaustive so a new key cannot go unspelled.
  // swiftlint:disable:next cyclomatic_complexity
  private static func ghosttyKeyNames(of key: ShortcutKey) -> [String] {
    switch key {
    case .character(sequenceStep): []

    case .character(let character):
      [String(character)] + (w3cName(of: character).map { [$0] } ?? [])

    case .function(let number): ["f\(number)"]
    case .tab: ["tab"]
    case .returnKey: ["enter"]
    case .space: ["space"]
    case .backspace: ["backspace"]
    case .forwardDelete: ["delete"]
    case .home: ["home"]
    case .end: ["end"]
    case .pageUp: ["page_up"]
    case .pageDown: ["page_down"]
    case .leftArrow: ["left"]
    case .rightArrow: ["right"]
    case .upArrow: ["up"]
    case .downArrow: ["down"]
    }
  }
}
