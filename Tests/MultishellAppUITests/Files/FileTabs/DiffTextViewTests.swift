import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewTests {
  @Test func removedAndAddedLinesAreCopiedAsADiffAndASplitSideCopiesPlainText() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 8)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("multishell-tests-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let removed = textView.displayText.range(ofRow: 3)
    let added = textView.displayText.range(ofRow: 5)
    let selection = (removed.lowerBound + 1)..<(added.lowerBound + 2)
    textView.setSelectedRange(NSRange(location: selection.lowerBound, length: selection.count))

    #expect(textView.writeSelection(to: pasteboard, types: [.string]))
    #expect(pasteboard.string(forType: .string) == "-gone 3\n line 4\n+new 5 名前\n")

    textView.copiesAsDiff = false
    #expect(textView.writeSelection(to: pasteboard, types: [.string]))
    #expect(pasteboard.string(forType: .string) == "one 3\nline 4\nne")
  }

  @Test func partOfOneChangedLineIsCopiedAsSelected() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 8)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("multishell-tests-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let removed = textView.displayText.range(ofRow: 3)
    textView.setSelectedRange(NSRange(location: removed.lowerBound + 1, length: 2))

    #expect(textView.writeSelection(to: pasteboard, types: [.string]))
    #expect(pasteboard.string(forType: .string) == "on")
  }
}
