import AppKit
import SwiftUI
import Testing

extension Color {
  func inSRGB() throws -> NSColor {
    try #require(NSColor(self).usingColorSpace(.sRGB))
  }
}
