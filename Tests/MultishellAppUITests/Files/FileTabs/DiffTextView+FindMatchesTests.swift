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

    let background = try #require(OffscreenWindow.backgroundPixels(of: view.textView))
    let painted = MagentaTheme.pixelCount(in: background)
    #expect(painted > 40, "two matches of two glyphs, \(painted) pixels")
  }
}
