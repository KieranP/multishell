import AppKit
import MultishellAppCore

/// The font families this Mac has, in the shape the picker wants. AppKit's
/// list; the ordering is `FontDetection`'s and is tested there.
@MainActor
enum InstalledFonts {
  /// Enumerated once and kept: a `@State` default is an ordinary expression,
  /// run whenever the `View` is built, which is every settings tab switch.
  private(set) static var all = detect()

  /// Replaces the cache, which Refresh must: the default above reads it
  /// again each time the window opens.
  @discardableResult
  static func reload() -> FontDetection {
    all = detect()
    return all
  }

  static func detect() -> FontDetection {
    let manager = NSFontManager.shared
    var monospaced: [String] = []
    var others: [String] = []
    for family in manager.availableFontFamilies where !family.hasPrefix(".") {
      if isMonospaced(family, manager: manager) {
        monospaced.append(family)
      } else {
        others.append(family)
      }
    }
    return FontDetection(monospaced: monospaced, others: others)
  }

  /// Fixed pitch by the family's first face. Some programming fonts are not
  /// marked so, which is why the picker also lists the rest.
  private static func isMonospaced(_ family: String, manager: NSFontManager) -> Bool {
    guard let members = manager.availableMembers(ofFontFamily: family),
      let name = members.first?.first as? String,
      let font = NSFont(name: name, size: 12)
    else { return false }
    return font.isFixedPitch || font.fontDescriptor.symbolicTraits.contains(.monoSpace)
  }
}
