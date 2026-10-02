import AppKit

struct InkedPixels {
  let bitmap: NSBitmapImageRep

  init(_ bitmap: NSBitmapImageRep) { self.bitmap = bitmap }

  func inked(_ x: Int, _ y: Int) -> Bool { (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.3 }

  var box: (minX: Int, maxX: Int, height: Int)? {
    let points = (0..<bitmap.pixelsWide).flatMap { x in
      (0..<bitmap.pixelsHigh).filter { inked(x, $0) }.map { (x, $0) }
    }
    guard let minX = points.map(\.0).min(), let maxX = points.map(\.0).max(),
      let minY = points.map(\.1).min(), let maxY = points.map(\.1).max()
    else { return nil }
    return (minX, maxX, maxY - minY + 1)
  }

  func inkedRows(inColumn x: Int) -> Int { (0..<bitmap.pixelsHigh).filter { inked(x, $0) }.count }

  func firstLineLeftmostColumn(lineHeight: Int) -> Int? {
    let columns = 0..<bitmap.pixelsWide
    guard let top = (0..<bitmap.pixelsHigh).first(where: { y in columns.contains { inked($0, y) } })
    else { return nil }
    let band = top..<min(top + lineHeight, bitmap.pixelsHigh)
    return columns.first { x in band.contains { inked(x, $0) } }
  }
}
