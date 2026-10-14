import AppKit
import MultishellAppCore

/// The font families this Mac has, in the shape the picker wants. AppKit's
/// list; the ordering is `FontDetection`'s and is tested there.
@MainActor
enum InstalledFonts {
  /// Enumerated once and kept: a `@State` default is an ordinary expression,
  /// run whenever the `View` is built, which is every settings page switch.
  static var detection = detect()

  /// Replaces the cache, which Refresh must: the Appearance page's `@State`
  /// default reads it again each time the window opens.
  static func refresh() -> FontDetection {
    detection = detect()
    return detection
  }

  /// Asked afresh, not of the cache, so a font installed since launch counts.
  static func lists(_ family: String) -> Bool {
    families(of: NSFontManager.shared).contains(family)
  }

  /// A family named with a leading dot is the system's own, never offered.
  private static func families(of manager: NSFontManager) -> [String] {
    manager.availableFontFamilies.filter { !$0.hasPrefix(".") }
  }

  private static func detect() -> FontDetection {
    let manager = NSFontManager.shared
    var monospaced: [String] = []
    var others: [String] = []
    for family in families(of: manager) {
      if isMonospaced(family, manager: manager) {
        monospaced.append(family)
      } else {
        others.append(family)
      }
    }
    return FontDetection(monospaced: monospaced, otherFamilies: others)
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
