import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffDocumentViewTests {
  /// Unclipped, TextKit 2's background covered the header and the tab strip
  /// above a file tab, which were laid out and never seen.
  @Test func theFileDrawsNothingOutsideItsOwnFrame() throws {
    let box = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    box.wantsLayer = true
    box.layer?.backgroundColor = NSColor.systemRed.cgColor
    let window = OffscreenWindow.holding(box, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 150)
    box.addSubview(view)
    view.show(
      DiffDisplayText(DiffDocumentFixture.lines(40), marksStaging: true),
      theme: Theme.builtins[0],
    )
    box.layoutSubtreeIfNeeded()
    box.display()

    let bitmap = try #require(OffscreenWindow.pixels(of: box))
    let scale = Double(bitmap.pixelsWide) / box.bounds.width
    let above = try #require(bitmap.colorAt(x: Int(200 * scale), y: Int(40 * scale)))
    #expect(above.redComponent > 0.8 && above.greenComponent < 0.4, "painted over at \(above)")
  }
}
