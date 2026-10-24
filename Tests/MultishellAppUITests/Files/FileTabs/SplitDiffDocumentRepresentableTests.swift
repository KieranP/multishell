import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct SplitDiffDocumentRepresentableTests {
  @Test func aStepAskedOfTheModelMovesTheShownSplitToTheChange() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let split = DiffDocumentFixture.split(rows: 400, removing: [300])
    let host = NSHostingView(
      rootView: SplitDiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        split: split,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    let view = try #require(host.descendants(of: SplitDiffDocumentView.self).first)

    harness.model.stepToChange(.next, in: tabID)
    OffscreenWindow.settle(until: { view.onDisk.topRow > 0 }, within: 2)

    #expect(view.onDisk.topRow == Double(300 - DiffRowGeometry.contextRowsAboveAChange))
  }

  @Test func aSplitRebuiltForATabBoxesTheChangeTheModelKept() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    let split = DiffDocumentFixture.split(rows: 400, removing: [300])
    harness.model.noteSteppedChangeAnchor(
      split.anchor(ofChangeAt: 300..<301),
      of: tabID,
    )
    let host = NSHostingView(
      rootView: SplitDiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        split: split,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    let view = try #require(host.descendants(of: SplitDiffDocumentView.self).first)
    #expect(view.onDisk.textView.steppedChange == 300..<301)
    #expect(view.committed.textView.steppedChange == 300..<301)
  }

  @Test func aSplitRebuiltWhoseKeptChangeIsGoneHasTheModelForgetIt() throws {
    let harness = ModelHarness()
    let tabID = UUID()
    harness.model.noteSteppedChangeAnchor(
      ChangeAnchor(
        committedDigest: 0,
        committedLineAbove: 5,
        committedLineBelow: 6,
        textAbove: nil,
        lineText: "nowhere",
      ),
      of: tabID,
    )
    let host = NSHostingView(
      rootView: SplitDiffDocumentRepresentable(
        model: harness.model,
        tabID: tabID,
        path: "notes.txt",
        split: DiffDocumentFixture.split(rows: 400, removing: [300]),
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    #expect(harness.model.steppedChangeAnchor(of: tabID) == nil)
  }
}
