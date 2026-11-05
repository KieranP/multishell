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

  /// Near magenta, anti-aliasing allowed for.
  private static func isMagenta(atX x: Int, y: Int, in bitmap: NSBitmapImageRep) -> Bool {
    guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
    return pixel.redComponent > 0.7 && pixel.blueComponent > 0.7 && pixel.greenComponent < 0.35
  }

  /// Magenta pixels right of `fromX`.
  static func pixelCount(in bitmap: NSBitmapImageRep, fromX: Int = 0) -> Int {
    pixelCount(in: bitmap, columns: fromX..<bitmap.pixelsWide)
  }

  /// Magenta pixels in `columns`.
  static func pixelCount(in bitmap: NSBitmapImageRep, columns: Range<Int>) -> Int {
    columns.clamped(to: 0..<bitmap.pixelsWide).reduce(0) { count, x in
      count + (0..<bitmap.pixelsHigh).count { isMagenta(atX: x, y: $0, in: bitmap) }
    }
  }

  /// The columns holding any magenta, left to right.
  static func inkedColumns(in bitmap: NSBitmapImageRep) -> [Int] {
    (0..<bitmap.pixelsWide).filter { x in
      (0..<bitmap.pixelsHigh).contains { isMagenta(atX: x, y: $0, in: bitmap) }
    }
  }

  /// The rows holding any magenta.
  static func inkedRowCount(in bitmap: NSBitmapImageRep) -> Int {
    (0..<bitmap.pixelsHigh).count { y in
      (0..<bitmap.pixelsWide).contains { isMagenta(atX: $0, y: y, in: bitmap) }
    }
  }
}
