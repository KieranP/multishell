import AppKit
import MultishellCore

extension RGB {
  func nsColor(alpha: Double = 1) -> NSColor {
    NSColor(
      srgbRed: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      alpha: alpha,
    )
  }
}
