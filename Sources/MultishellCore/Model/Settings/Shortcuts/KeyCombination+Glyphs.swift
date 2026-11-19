extension KeyCombination {
  /// As a menu draws it, `⇧⌘K`, `⌃⇥`.
  public var glyphs: String {
    modifiers.glyphs + Self.glyph(for: key)
  }

  /// Reads what `glyphs` writes, a capital letter being that letter alone:
  /// `⇧⌘K` holds Shift because of its `⇧`.
  public init?(glyphs text: String) {
    var modifiers: ShortcutModifiers = []
    var rest = Substring(text)
    while let first = rest.first,
      let modifier = ShortcutModifiers.menuOrder.first(where: { $0.glyph == first })?.modifier
    {
      guard !modifiers.contains(modifier) else { return nil }
      modifiers.insert(modifier)
      rest = rest.dropFirst()
    }
    guard let key = Self.key(glyph: String(rest)) else { return nil }
    self.init(key, modifiers)
  }

  private static func glyph(for key: ShortcutKey) -> String {
    switch key {
    case .character(let character): capital(of: character)
    case .function(let number): "F\(number)"
    default: ShortcutKey.named.first { $0.key == key }?.glyph ?? ""
    }
  }

  /// The character itself where its capital would read back as another key:
  /// ß capitalises to SS, and Turkish ı to I, which is i's.
  private static func capital(of character: Character) -> String {
    let capital = character.uppercased()
    let readsBack = capital.count == 1 && capital.lowercased() == String(character)
    return readsBack ? capital : String(character)
  }

  private static func key(glyph: String) -> ShortcutKey? {
    if let named = ShortcutKey.named.first(where: { $0.glyph == glyph }) { return named.key }
    if glyph.count > 1, glyph.hasPrefix("F"), let number = Int(glyph.dropFirst()),
      ShortcutKey.functionNumbers.contains(number)
    {
      return .function(number)
    }
    guard glyph.count == 1, let character = glyph.first, isTypable(character) else { return nil }
    return .character(character)
  }
}
