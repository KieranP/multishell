import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewTests {
  @Test func aSelectionTouchingAChangeIsCopiedAsADiffAndASplitSideCopiesPlainText() throws {
    let (view, window) = DiffDocumentFixture.shown(rows: 8)
    defer { withExtendedLifetime(window) {} }
    let textView = view.textView
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("multishell-tests-\(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    let removed = textView.displayText.range(ofRow: 3)
    textView.setSelectedRange(NSRange(location: removed.lowerBound + 1, length: 2))

    #expect(textView.writeSelection(to: pasteboard, types: [.string]))
    #expect(pasteboard.string(forType: .string) == "-gone 3\n")

    textView.copiesAsDiff = false
    #expect(textView.writeSelection(to: pasteboard, types: [.string]))
    #expect(pasteboard.string(forType: .string) == "on")
  }
}
