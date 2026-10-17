import AppKit
import MultishellCore

extension RGB {
  var nsColor: NSColor {
    NSColor(
      srgbRed: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      alpha: opacity,
    )
  }
}
