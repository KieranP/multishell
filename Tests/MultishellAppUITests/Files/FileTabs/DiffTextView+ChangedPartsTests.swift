import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewChangedPartsTests {
  @Test func theWordsALineChangedArePaintedDarkerThanTheRestOfItsRow() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 14))
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 120)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let rows = FileTabRows(lines: [
      DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "let total = 1"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "let total = 10"),
    ])
    view.show(rows.displayText, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    let textView = view.textView
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(textView.bounds.width),
        pixelsHigh: Int(textView.bounds.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0,
      )
    )
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    textView.drawBackground(in: textView.bounds)
    NSGraphicsContext.restoreGraphicsState()

    for row in 0..<2 {
      let middle = textView.geometry.top(ofRow: row) + textView.geometry.rowHeight / 2
      let y = bitmap.pixelsHigh - 1 - Int(middle)
      let lineTint = try #require(bitmap.colorAt(x: bitmap.pixelsWide - 2, y: y))
      let darker = (0..<bitmap.pixelsWide).count { x in
        guard let colour = bitmap.colorAt(x: x, y: y) else { return false }
        return abs(colour.greenComponent - lineTint.greenComponent) > 0.03
          || abs(colour.redComponent - lineTint.redComponent) > 0.03
      }
      #expect(darker > 4, "row \(row)")
    }
  }
}
