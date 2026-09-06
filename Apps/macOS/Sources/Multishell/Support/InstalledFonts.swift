import AppKit
import MultishellAppCore

/// The font families this Mac has, sorted into the shape the terminal font
/// picker wants. AppKit's list, so it lives beside the view; the ordering
/// and the "not installed" row are `FontDetection`'s and are tested there.
enum InstalledFonts {
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
