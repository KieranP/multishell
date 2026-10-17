import AppKit
import MultishellCore

@testable import MultishellAppCore
@testable import MultishellAppUI

/// A file tab's view laid out in a window never shown, over rows of every
/// kind: a removal every seventh row, an addition two after it.
@MainActor
enum DiffDocumentFixture {
  static func lines(_ count: Int) -> [DiffLine] {
    (0..<count).map { index in
      switch index % 7 {
      case 3: DiffLine(kind: .removed, oldNumber: index + 1, newNumber: nil, text: "gone \(index)")

      case 5:
        DiffLine(
          kind: .added,
          oldNumber: nil,
          newNumber: index + 1,
          text: "new \(index) 名前",
          isStaged: index.isMultiple(of: 2),
        )

      default:
        DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "line \(index)")
      }
    }
  }

  /// One context row per text, numbered from 1.
  static func contextLines(_ texts: [String]) -> DiffDisplayText {
    DiffDisplayText(
      texts.enumerated().map { index, text in
        DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: text)
      }
    )
  }

  /// One context row per text, in a view 200 points high.
  static func shown(
    contextLines texts: [String],
    fontSize: Double = 12,
    width: Double = 500,
  ) -> (DiffDocumentView, NSWindow) {
    let view = DiffDocumentView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: fontSize)
    )
    view.frame = NSRect(x: 0, y: 0, width: width, height: 200)
    let window = OffscreenWindow.holding(view, deferred: false)
    view.show(contextLines(texts), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    return (view, window)
  }

  static func shown(rows: Int) -> (DiffDocumentView, NSWindow) {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
    let window = OffscreenWindow.holding(view, deferred: false)
    view.show(DiffDisplayText(lines(rows)), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    return (view, window)
  }
}
