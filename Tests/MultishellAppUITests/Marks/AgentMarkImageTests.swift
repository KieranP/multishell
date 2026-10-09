import AppKit
import Testing

@testable import MultishellAppUI

@Suite @MainActor
struct AgentMarkImageTests {
  @Test func theShellGlyphKeepsBothSidesOfItsWindow() throws {
    let image = try #require(AgentMarkImage.nsImage(for: nil, scale: 4))
    let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
    let ink = InkedPixels(bitmap)
    let glyph = try #require(ink.box)

    for column in [glyph.minX, glyph.maxX] {
      let run = ink.inkedRows(inColumn: column)
      #expect(
        Double(run) > Double(glyph.height) * 0.5,
        "column \(column) is inked on \(run) of the glyph's \(glyph.height) rows",
      )
    }
  }
}
