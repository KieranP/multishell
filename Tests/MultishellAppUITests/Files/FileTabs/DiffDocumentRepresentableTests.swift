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
    #expect(textView.selectedRange() == NSRange(match))
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

  @Test func aStepAskedOfTheModelMovesTheShownViewToTheChange() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = DiffDocumentFixture.text(rows: 400, adding: [300])
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: text,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    let view = try #require(host.descendants(of: DiffDocumentView.self).first)

    harness.model.stepToChange(.next, in: tabID)
    OffscreenWindow.settle(until: { view.topRow > 0 }, within: 2)

    #expect(view.topRow == Double(300 - DiffRowGeometry.contextRowsAboveAChange))
  }

  @Test func aViewRebuiltForATabBoxesTheChangeTheModelKept() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = DiffDocumentFixture.text(rows: 400, adding: [300])
    harness.model.noteSteppedChangeAnchor(
      text.anchor(ofChangeAt: 300..<301),
      of: tabID,
    )
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: text,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    let view = try #require(host.descendants(of: DiffDocumentView.self).first)
    #expect(view.textView.steppedChange == 300..<301)
  }

  @Test func aViewRebuiltWithItsFindBarUpKeepsTheBoxTheModelKept() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = DiffDocumentFixture.text(rows: 400, adding: [300])
    harness.model.noteSteppedChangeAnchor(
      text.anchor(ofChangeAt: 300..<301),
      of: tabID,
    )
    harness.model.noteFileFindShown(FileFindShown(text: "line", selectionMoves: 1), of: tabID)
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: text,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(
          text: "line",
          matches: [text.range(ofRow: 100)],
          selected: 0,
          selectionMoves: 1,
        ),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    let view = try #require(host.descendants(of: DiffDocumentView.self).first)
    #expect(view.textView.steppedChange == 300..<301)
  }

  @Test func aViewRebuiltWithAMatchInsideTheBoxSelectsTheMatch() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let text = DiffDocumentFixture.text(rows: 400, adding: Set(300..<305))
    let match = text.range(ofRow: 303)
    harness.model.noteSteppedChangeAnchor(
      text.anchor(ofChangeAt: 300..<305),
      of: tabID,
    )
    harness.model.noteFileFindShown(FileFindShown(text: "new 303", selectionMoves: 1), of: tabID)
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: text,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "new 303", matches: [match], selected: 0, selectionMoves: 1),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    let view = try #require(host.descendants(of: DiffDocumentView.self).first)
    #expect(view.textView.selectedRange() == NSRange(match))
    #expect(view.textView.steppedChange == 300..<305)
  }

  @Test func aViewRebuiltWhoseKeptChangeIsGoneHasTheModelForgetIt() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    harness.model.noteSteppedChangeAnchor(
      ChangeAnchor(
        headDigest: 0,
        headLineAbove: 5,
        headLineBelow: 6,
        textAbove: nil,
        lineText: "nowhere",
      ),
      of: tabID,
    )
    let host = NSHostingView(
      rootView: DiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        text: DiffDocumentFixture.text(rows: 400, adding: [300]),
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    #expect(harness.model.steppedChangeAnchor(of: tabID) == nil)
  }
}
