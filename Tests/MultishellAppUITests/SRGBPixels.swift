import AppKit

/// A bitmap's pixels as `colorAt(x:y:)` reads them in sRGB, converted once per pixel word:
/// converting every pixel took seconds a bitmap, which holds a few hundred distinct words.
final class SRGBPixels {
  private let bitmap: NSBitmapImageRep
  private let words: UnsafeRawPointer?
  private var readings: [UInt32: NSColor?] = [:]

  var width: Int { bitmap.pixelsWide }
  var height: Int { bitmap.pixelsHigh }

  init(_ bitmap: NSBitmapImageRep) {
    self.bitmap = bitmap
    let isOneWordAPixel =
      bitmap.bitsPerSample == 8 && bitmap.bitsPerPixel == 32 && !bitmap.isPlanar
    words = isOneWordAPixel ? bitmap.bitmapData.map(UnsafeRawPointer.init) : nil
  }

  func color(x: Int, y: Int) -> NSColor? {
    guard let word = word(x: x, y: y) else { return converted(x: x, y: y) }
    if let reading = readings[word] { return reading }
    let reading = converted(x: x, y: y)
    readings[word] = reading
    return reading
  }

  /// Where each distinct pixel word first appears, reading row by row; a bitmap that is
  /// not one word a pixel gives every position.
  func firstPositionOfEachDistinctPixel() -> [(x: Int, y: Int)] {
    guard words != nil else {
      return (0..<height).flatMap { y in (0..<width).map { (x: $0, y: y) } }
    }
    var firstSeen: [UInt32: (x: Int, y: Int)] = [:]
    for y in 0..<height {
      var previous: UInt32?
      for x in 0..<width {
        let word = word(x: x, y: y)
        guard word != previous, let word else { continue }
        previous = word
        if firstSeen[word] == nil { firstSeen[word] = (x, y) }
      }
    }
    return Array(firstSeen.values)
  }

  private func word(x: Int, y: Int) -> UInt32? {
    words?.loadUnaligned(fromByteOffset: y * bitmap.bytesPerRow + x * 4, as: UInt32.self)
  }

  private func converted(x: Int, y: Int) -> NSColor? {
    bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
  }
}
