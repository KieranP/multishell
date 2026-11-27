extension ShortcutModifiers {
  /// The modifiers alone in menu order, `⌃⌥⇧⌘`, as recorders, menus and shortcuts show them.
  public var glyphs: String {
    String(Self.menuOrder.filter { contains($0.modifier) }.map(\.glyph))
  }
}
