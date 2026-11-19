extension ShortcutModifiers {
  /// The modifiers alone, `⌃⌥`, as a recorder shows them while they are held.
  public var glyphs: String {
    String(Self.menuOrder.filter { contains($0.modifier) }.map(\.glyph))
  }
}
