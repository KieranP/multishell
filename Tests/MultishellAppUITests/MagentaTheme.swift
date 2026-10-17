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

  /// Pixels near magenta, anti-aliasing allowed for, right of `fromX`.
  static func pixelCount(in bitmap: NSBitmapImageRep, fromX: Int = 0) -> Int {
    var count = 0
    for x in fromX..<bitmap.pixelsWide {
      for y in 0..<bitmap.pixelsHigh {
        guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        if pixel.redComponent > 0.7, pixel.blueComponent > 0.7, pixel.greenComponent < 0.35 {
          count += 1
        }
      }
    }
    return count
  }
}
