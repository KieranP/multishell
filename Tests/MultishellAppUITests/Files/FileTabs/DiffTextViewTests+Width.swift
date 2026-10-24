import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffTextViewTests {
  @Test(arguments: [
    String(repeating: String(repeating: "a", count: 80) + "\r", count: 5),
    String(repeating: "\u{2E3B}", count: 10),
    String(repeating: "\u{FDFD}", count: 10),
  ])
  func theViewIsAsWideAsItsWidestDrawnLine(widest: String) throws {
    let (view, window) = DiffDocumentFixture.shown(
      contextLines: [String(repeating: "x", count: 40), widest],
      width: 300,
    )
    defer { withExtendedLifetime(window) {} }
    let text = view.textView.displayText
    let drawn = (text.drawnString as NSString).substring(with: NSRange(text.range(ofRow: 1)))

    let needed = (drawn as NSString).size(withAttributes: [
      .font: DiffRowGeometry(fontFamily: nil, fontSize: 12).font
    ]).width

    try #require(needed > view.textView.enclosingScrollView?.contentView.bounds.width ?? 0)
    #expect(view.textView.frame.width >= needed)
  }

  @Test(arguments: ["Helvetica", "American Typewriter", "Menlo"])
  func aLongLineFitsTheContainerInAnyFileFont(family: String) {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: family, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let line = String(repeating: "W", count: 200)
    view.show(
      DiffDisplayText(
        [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: line)],
        marksStaging: true,
      ),
      theme: Theme.builtins[0],
    )

    let needed = (line as NSString).size(withAttributes: [.font: view.textView.geometry.font]).width

    #expect(view.textView.textContainer?.size.width ?? 0 >= needed)
  }
}
