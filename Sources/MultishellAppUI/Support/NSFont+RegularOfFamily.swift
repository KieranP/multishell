import AppKit

extension NSFont {
  /// `NSFontManager`'s weights run 0 to 15, 5 being regular.
  private static let regularWeight = 5

  /// `nil` where this Mac lacks the family.
  static func regular(ofFamily family: String, size: CGFloat) -> NSFont? {
    NSFontManager.shared.font(withFamily: family, traits: [], weight: regularWeight, size: size)
  }
}
