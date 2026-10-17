import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// TextKit 2's rendering attributes marked no line view for drawing; the text
/// view's own pass is what `needsDisplay` redraws, so the matches paint there.
@Suite @MainActor
struct DiffTextViewFindMatchesTests {
  private static let tint = NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)

  private static func backgroundPixels(of view: NSTextView) throws -> NSBitmapImageRep {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(view.bounds.width),
        pixelsHigh: Int(view.bounds.height),
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
    view.drawBackground(in: view.bounds)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
  }

  @Test func everyMatchIsPaintedByTheTextViewsOwnPassWithTheSelectionLeftWhereItWas() throws {
    let (view, window) = DiffDocumentFixture.shown(
      contextLines: ["aaa", "bbb xx", "ccc", "ddd xx"],
      fontSize: 14,
    )
    defer { withExtendedLifetime(window) {} }
    let text = view.textView.displayText
    let matches = FileFindResult.searching("xx", in: text, after: nil, keepingSelection: false)
      .matches
    let find = FindMatchesShown(text: "xx", matches: matches, selected: 0, selectionMoves: 1)

    view.textView.showFindMatches(find, after: find, isFirstPaint: false, tint: Self.tint)

    #expect(view.textView.selectedRange() == NSRange(location: 0, length: 0))

    let painted = MagentaTheme.pixelCount(in: try Self.backgroundPixels(of: view.textView))
    #expect(painted > 40, "two matches of two glyphs, \(painted) pixels")
  }
}
