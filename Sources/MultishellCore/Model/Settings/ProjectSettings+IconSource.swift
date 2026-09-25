extension ProjectSettings {
  /// Whether the glyph or tint `layered(over:)` draws is the repository's
  /// file's, read as it reads them: a glyph that is not a symbol name is a gap.
  public func takesIconFromSharedFile(_ shared: SharedProjectSettings?) -> Bool {
    (ProjectIcon.normalizedGlyph(iconGlyph) == nil
      && ProjectIcon.normalizedGlyph(shared?.iconGlyph) != nil)
      || (iconTint == nil && ProjectIcon.validTint(shared?.iconTint) != nil)
  }
}
