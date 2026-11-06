/// Whether a chrome glyph button is lit: under the pointer and enabled, so a
/// disabled one never reads as a button. See Docs/design/appearance/window-chrome.md.
public enum GlyphButtonLight {
  public static func isLit(isHovered: Bool, isEnabled: Bool) -> Bool {
    isHovered && isEnabled
  }

  /// A toggle that is on keeps its colour lit, the square saying the pointer is
  /// on it; one off turns to the area's text, as every other glyph does.
  public static func turnsToTextWhenLit(isOn: Bool) -> Bool {
    !isOn
  }
}
