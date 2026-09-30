import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AgentMarkImageTests {
  @Test func theShellGlyphKeepsBothSidesOfItsWindow() throws {
    let image = try #require(AgentMarkImage.nsImage(for: nil, scale: 4))
    let rep = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
    let ink = InkBounds(rep)
    let glyph = try #require(ink.box)

    for column in [glyph.minX, glyph.maxX] {
      let run = ink.inkedRows(inColumn: column)
      #expect(
        Double(run) > Double(glyph.height) * 0.5,
        "column \(column) is inked on \(run) of the glyph's \(glyph.height) rows")
    }
  }
}

private struct InkBounds {
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
}
