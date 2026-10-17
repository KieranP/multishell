import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffDocumentRepresentableTests {
  private static let text = DiffDocumentFixture.contextLines((1...400).map { "line \($0)" })

  @Test func aViewRebuiltWithItsFindBarUpReturnsToItsScrollWithItsMatchStillSelected() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = Self.text
    harness.model.noteFileTabScrolled(
      tabID,
      to: FileTabScroll(line: 120, isHEADsLine: false, rowsFromLine: 0, x: 0),
    )
    harness.model.noteFileFindShown(FileFindShown(text: "line", selectionMoves: 1), of: tabID)
    let match = text.range(ofRow: 300)
    let representable = DiffDocumentRepresentable(
      model: harness.model,
      tabID: tabID,
      path: "notes.txt",
      text: text,
      theme: Theme.builtins[0],
      font: FileFont(family: nil, size: 12),
      find: FindMatchesShown(text: "line", matches: [match], selected: 0, selectionMoves: 1),
    )

    let host = NSHostingView(rootView: representable)
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    host.display()
    let topRow = host.descendants(of: DiffDocumentView.self).first?.topRow

    let row = try #require(topRow)
    #expect(row.rounded() == 119, "top row \(row)")
    let textView = try #require(host.descendants(of: DiffDocumentView.self).first?.textView)
    #expect(textView.selectedRange() == NSRange(location: match.lowerBound, length: match.count))
  }

  @Test func aSearchMadeBeforeTheRebuiltViewDrewIsScrolledTo() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = Self.text
    harness.model.noteFileTabScrolled(
      tabID,
      to: FileTabScroll(line: 120, isHEADsLine: false, rowsFromLine: 0, x: 0),
    )
    harness.model.noteFileFindShown(FileFindShown(text: "line", selectionMoves: 1), of: tabID)
    let match = text.range(ofRow: 300)
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: text,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "line 3", matches: [match], selected: 0, selectionMoves: 2),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    host.display()

    let row = try #require(host.descendants(of: DiffDocumentView.self).first?.topRow)
    #expect(row > 250, "top row \(row)")
  }
}
