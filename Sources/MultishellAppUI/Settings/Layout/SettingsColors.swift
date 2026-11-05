import AppKit
import SwiftUI

/// The settings window's own colours, light and dark, as the approved mockup
/// drew them; the window follows the system appearance, not the theme.
enum SettingsColors {
  /// Behind the pages' cards.
  static let page = adaptive(light: 0xEFEFF1, dark: 0x1F1F21)
  /// The page header's band.
  static let bar = adaptive(light: 0xF7F7F9, dark: 0x2A2A2D)
  static let card = adaptive(light: 0xFFFFFF, dark: 0x29292C)
  /// A pop-up menu's or a button's face.
  static let control = adaptive(light: 0xFFFFFF, dark: 0x3D3D41)
  static let controlEdge = Color.primary.opacity(0.13)
  /// Inside a text box: a hook's script or a file list.
  static let field = adaptive(light: 0xFFFFFF, dark: 0x1A1A1C)
  static let sidebar = adaptive(light: 0xE7E7EB, dark: 0x252528)
  /// Rules between rows and around cards.
  static let rule = Color.primary.opacity(0.08)
  /// A dashed or drawn outline: the Same button's.
  static let outline = Color.primary.opacity(0.16)
  /// The search field's well and a sidebar row under the pointer.
  static let well = Color.primary.opacity(0.085)
  static let secondaryText = adaptive(light: 0x6E6E73, dark: 0x9B9BA1)
  static let faintText = adaptive(light: 0xA4A4AA, dark: 0x616168)

  private static func adaptive(light: Int, dark: Int) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return rgb(isDark ? dark : light)
      }
    )
  }

  private static func rgb(_ value: Int) -> NSColor {
    NSColor(
      srgbRed: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      alpha: 1,
    )
  }
}
