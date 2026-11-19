extension KeyCombination {
  /// Glyphs naming keys this has no case for, which no key types as a character.
  private static let keyNameGlyphs: Set<Character> = ["⏎", "⌤", "⎋", "⇪", "⏏", "⌽"]

  /// Punctuation by name in the state file, so `+` never parts a combination
  /// and a quote needs no escaping.
  private static let punctuationWords: [Character: String] = [
    "`": "backquote", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right",
    "\\": "backslash", ";": "semicolon", "'": "quote", ",": "comma", ".": "period", "/": "slash",
    "+": "plus",
  ]

  /// As the state file keeps it, modifiers in menu order: `ctrl+shift+tab`,
  /// `cmd+backslash`.
  public var spelled: String {
    let words = ShortcutModifiers.menuOrder.filter { modifiers.contains($0.modifier) }.map(\.word)
    return (words + [Self.word(for: key)]).joined(separator: "+")
  }

  /// `nil` for a word this does not know or a modifier given twice. Any case,
  /// any order of modifiers, and a key may be its own character: `cmd+\`.
  public init?(spelled text: String) {
    let lowered = text.lowercased()
    var parts = lowered.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
    if lowered.hasSuffix("++") { parts = Array(parts.dropLast(2)) + ["+"] }
    guard let keyWord = parts.last, let key = Self.key(named: keyWord) else { return nil }
    var modifiers: ShortcutModifiers = []
    for word in parts.dropLast() {
      guard let modifier = ShortcutModifiers.menuOrder.first(where: { $0.word == word })?.modifier,
        !modifiers.contains(modifier)
      else { return nil }
      modifiers.insert(modifier)
    }
    self.init(key, modifiers)
  }

  private static func word(for key: ShortcutKey) -> String {
    switch key {
    case .character(let character): punctuationWords[character] ?? String(character)
    case .function(let number): "f\(number)"
    default: ShortcutKey.named.first { $0.key == key }?.word ?? ""
    }
  }

  private static func key(named word: String) -> ShortcutKey? {
    if let named = ShortcutKey.named.first(where: { $0.word == word }) { return named.key }
    // A glyph pasted from the page, ⌘←, names its key, not a character no key types.
    if let named = ShortcutKey.named.first(where: { $0.glyph == word }) { return named.key }
    if let character = punctuationWords.first(where: { $0.value == word })?.key {
      return .character(character)
    }
    if word.count > 1, word.hasPrefix("f"), let number = Int(word.dropFirst()),
      ShortcutKey.functionNumbers.contains(number)
    {
      return .function(number)
    }
    guard word.count == 1, let character = word.first, isTypable(character) else { return nil }
    return .character(character)
  }

  /// A space, a modifier's or a key's glyph, a control code or one of AppKit's
  /// private-use keys is no character key; the named keys stand for those with a word.
  public static func isTypable(_ character: Character) -> Bool {
    !character.isWhitespace && !keyNameGlyphs.contains(character)
      && !ShortcutModifiers.menuOrder.contains { $0.glyph == character }
      && character.unicodeScalars.allSatisfy { scalar in
        ![.control, .privateUse, .format].contains(scalar.properties.generalCategory)
      }
  }
}
