import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewShownTextTests {
  private static let before: [(DiffLine.Kind, String)] = [
    (.context, "let a = 1 // one"), (.context, "/* open"), (.context, "close */ let b"),
    (.removed, "let gone = 2"), (.added, "let kept = 3"), (.context, "let tail = 4"),
  ]

  private static let edits: [[(DiffLine.Kind, String)]] = [
    before,
    [(.context, "let first = 0")] + before,
    Array(before.dropLast()),
    before.map { $0.1 == "close */ let b" ? (.context, "close let b") : $0 },
    before.map { $0.0 == .removed ? (.context, $0.1) : $0 },
    before + [(.added, "let more = 5 // new")],
    [(.context, "let only = 1")],
  ]

  private static func text(_ rows: [(DiffLine.Kind, String)]) -> DiffDisplayText {
    DiffDisplayText(
      rows.enumerated().map { index, row in
        DiffLine(
          kind: row.0,
          oldNumber: row.0 == .added ? nil : index + 1,
          newNumber: row.0 == .removed ? nil : index + 1,
          text: row.1,
        )
      }
    )
  }

  /// A stand-in for tree-sitter: `let` a keyword, `//` to the line's end and
  /// `/* … */` across lines a comment.
  private static func runs(for text: DiffDisplayText) -> [HighlightSpan] {
    let string = text.string as NSString
    var spans: [HighlightSpan] = []
    for pattern in ["let", "//[^\\n]*", "/\\*[\\s\\S]*?\\*/"] {
      let expression = try? NSRegularExpression(pattern: pattern)
      for match in expression?.matches(in: text.string, range: NSRange(0..<string.length)) ?? [] {
        let range = match.range.location..<NSMaxRange(match.range)
        spans.append(HighlightSpan(range: range, role: pattern == "let" ? .keyword : .comment))
      }
    }
    return HighlightSpan.nonOverlappingRuns(spans, length: string.length)
  }

  private static func attributes(of view: DiffTextView) -> [String] {
    guard let storage = view.textStorage else { return [] }
    return (0..<storage.length).map { offset in
      let colour = storage.attribute(.foregroundColor, at: offset, effectiveRange: nil)
      let font = storage.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
      return
        "\(String(describing: colour)) \(font?.fontDescriptor.symbolicTraits.contains(.italic) == true)"
    }
  }

  private static func shown(_ steps: [DiffDisplayText]) async -> DiffTextView {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
    for text in steps {
      view.show(text, theme: Theme.builtins[0])
      _ = await view.textView.applyHighlights(runs(for: text), for: text, theme: Theme.builtins[0])
    }
    return view.textView
  }

  @Test(arguments: 0..<7)
  func aReReadColouredInPlaceEndsAsAFreshShowOfItsText(edit: Int) async {
    let after = Self.text(Self.edits[edit])

    let reRead = await Self.shown([Self.text(Self.before), after])
    let fresh = await Self.shown([after])

    #expect(reRead.textStorage?.string == fresh.textStorage?.string)
    #expect(Self.attributes(of: reRead) == Self.attributes(of: fresh))
  }
}
