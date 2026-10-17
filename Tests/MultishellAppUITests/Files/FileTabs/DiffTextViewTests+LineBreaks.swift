import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffTextViewTests {
  @Test(arguments: ["\r", "\u{2028}", "\u{2029}", "\u{85}", "\u{0C}", "\u{0B}"])
  func aBreakInsideALineLeavesItOneRow(separator: String) throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: ["a\(separator)b", "c"])
    defer { withExtendedLifetime(window) {} }
    let layoutManager = try #require(view.textView.textLayoutManager)
    layoutManager.ensureLayout(for: layoutManager.documentRange)

    var lineFragments = 0
    layoutManager.enumerateTextLayoutFragments(from: nil, options: [.ensuresLayout]) { fragment in
      lineFragments += fragment.textLineFragments.count
      return true
    }

    #expect(lineFragments == 2)
  }
}
