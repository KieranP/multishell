import AppKit
import Foundation

@testable import MultishellCore

/// A theme with the given `ui` keys set to magenta, a colour nothing else in the
/// window is, so a rendering shows whether a part reads its key or the system's.
enum MagentaTheme {
  static func with(_ keys: [InterfaceSection: [InterfaceColorKey]]) throws -> Theme {
    let entries = keys.map { section, colorKeys in
      let colours = colorKeys.map { ##""\##($0.rawValue)": "#ff00ff""## }.joined(separator: ", ")
      return #""\#(section.rawValue)": { \#(colours) }"#
    }
    let json =
      #"{ "id": "magenta", "name": "Magenta", "ui": { \#(entries.joined(separator: ", ")) } }"#
    return try JSONDecoder().decode(Theme.self, from: Data(json.utf8))
  }

  /// Loose bounds, as anti-aliasing blends the edges.
  private static func isMagenta(atX x: Int, y: Int, in pixels: SRGBPixels) -> Bool {
    guard let pixel = pixels.color(x: x, y: y) else { return false }
    return pixel.redComponent > 0.7 && pixel.blueComponent > 0.7 && pixel.greenComponent < 0.35
  }

  static func pixelCount(in bitmap: NSBitmapImageRep, fromX: Int = 0) -> Int {
    pixelCount(in: bitmap, columns: fromX..<bitmap.pixelsWide)
  }

  static func pixelCount(in bitmap: NSBitmapImageRep, columns: Range<Int>) -> Int {
    let pixels = SRGBPixels(bitmap)
    return columns.clamped(to: 0..<pixels.width).reduce(0) { count, x in
      count + (0..<pixels.height).count { isMagenta(atX: x, y: $0, in: pixels) }
    }
  }

  static func inkedColumns(in bitmap: NSBitmapImageRep) -> [Int] {
    let pixels = SRGBPixels(bitmap)
    return (0..<pixels.width).filter { x in
      (0..<pixels.height).contains { isMagenta(atX: x, y: $0, in: pixels) }
    }
  }

  static func inkedRowCount(in bitmap: NSBitmapImageRep) -> Int {
    let pixels = SRGBPixels(bitmap)
    return (0..<pixels.height).count { y in
      (0..<pixels.width).contains { isMagenta(atX: $0, y: y, in: pixels) }
    }
  }
}
