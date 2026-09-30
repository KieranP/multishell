import AppKit

struct InkedPixels {
  let rep: NSBitmapImageRep

  init(_ rep: NSBitmapImageRep) { self.rep = rep }

  func inked(_ x: Int, _ y: Int) -> Bool { (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.3 }

  var box: (minX: Int, maxX: Int, height: Int)? {
    let points = (0..<rep.pixelsWide).flatMap { x in
      (0..<rep.pixelsHigh).filter { inked(x, $0) }.map { (x, $0) }
    }
    guard let minX = points.map(\.0).min(), let maxX = points.map(\.0).max(),
      let minY = points.map(\.1).min(), let maxY = points.map(\.1).max()
    else { return nil }
    return (minX, maxX, maxY - minY + 1)
  }

  func inkedRows(inColumn x: Int) -> Int { (0..<rep.pixelsHigh).filter { inked(x, $0) }.count }

  func firstLineLeftmostColumn(lineHeight: Int) -> Int? {
    let columns = 0..<rep.pixelsWide
    guard let top = (0..<rep.pixelsHigh).first(where: { y in columns.contains { inked($0, y) } })
    else { return nil }
    let band = top..<min(top + lineHeight, rep.pixelsHigh)
    return columns.first { x in band.contains { inked(x, $0) } }
  }
}
