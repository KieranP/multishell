import AppKit
import MultishellGitKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AllChangesDocumentRepresentableTests {
  private static func reading(paths: [String], rows: Int) -> AllChangesReading {
    let changes = paths.map { AllChangesFileChange(path: $0, kind: .modified, lineCounts: nil) }
    return AllChangesReading(
      listed: changes,
      files: changes.map { change in
        let lines = (1...rows).map { line in
          DiffLine(
            kind: line == rows / 2 ? .added : .context,
            oldNumber: line == rows / 2 ? nil : line,
            newNumber: line,
            text: "\(change.path) \(line)",
          )
        }
        let rows = FileTabRows(lines: lines, marksStaging: true)
        return AllChangesFile(
          change: change,
          content: .read(FileTabReading(content: .text(rows), isFileGone: false)),
          signature: nil,
        )
      },
    )
  }

  private static func hosted(
    _ document: AllChangesDocument,
    in harness: ModelHarness,
    tab: AllChangesTab,
  ) -> (DiffDocumentView?, NSWindow) {
    let host = NSHostingView(
      rootView: AllChangesDocumentRepresentable(
        model: harness.model,
        tab: tab,
        document: document,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    host.layoutSubtreeIfNeeded()
    host.display()
    return (host.descendants(of: DiffDocumentView.self).first, window)
  }

  @Test func eachFilesHeaderOpensAGapAboveItsFirstRow() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt"], rows: 9),
      collapsed: [],
      heldOpen: [:],
    )

    let (view, window) = Self.hosted(document, in: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    let geometry = try #require(view?.textView.geometry)
    let header = harness.model.metrics.allChangesHeaderHeight
    #expect(abs(geometry.top(ofRow: 0) - (DiffRowGeometry.verticalInset + header)) < 0.001)
    let second = document.sections[1].rows.lowerBound
    #expect(
      abs(geometry.top(ofRow: second) - (geometry.gapTop(afterRow: second - 1) + header)) < 0.001
    )
  }

  @Test func aSavedScrollReturnsToItsFilesLineThoughFilesAboveChanged() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt", "c.txt"], rows: 200),
      collapsed: ["a.txt"],
      heldOpen: ["b.txt": [AllChangesLineSpan(side: .onDisk, lines: 1...200)]],
    )
    harness.model.noteAllChangesScrolled(
      tab.id,
      to: AllChangesScroll(
        path: "b.txt",
        scroll: FileTabScroll(line: 150, isCommittedLine: false, rowsFromLine: 0, x: 0),
      ),
    )

    let (view, window) = Self.hosted(document, in: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    let top = try #require(view?.topRow)
    #expect(document.text.lines[Int(top.rounded())].text == "b.txt 150")
  }

  @Test func aSplitOpensEachHeadersGapInBothColumnsAndHostsItAcrossThem() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt"], rows: 9),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )
    let split = try #require(document.split)
    let host = NSHostingView(
      rootView: AllChangesSplitDocumentRepresentable(
        model: harness.model,
        tab: tab,
        document: document,
        split: split,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 600, height: 300)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    host.display()

    let view = try #require(host.descendants(of: SplitDiffDocumentView.self).first)
    let header = harness.model.metrics.allChangesHeaderHeight
    for column in [view.committed, view.onDisk] {
      let top = column.textView.geometry.top(ofRow: 0)
      #expect(abs(top - (DiffRowGeometry.verticalInset + header)) < 0.001)
    }
    let hosted = view.spanningGapViews.subviews.filter { !$0.isHidden }.map(\.frame.width)
    let boxWidth = view.bounds.width - view.leadingInset - view.scrollerMargin
    #expect(hosted.count == 2 && hosted.allSatisfy { $0 == boxWidth })
  }

  @Test func bothSplitColumnsStayOnTheSameOffsetScrolledFromEitherSideAndToTheEnd() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt", "c.txt"], rows: 60),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )
    let split = try #require(document.split)
    let host = NSHostingView(
      rootView: AllChangesSplitDocumentRepresentable(
        model: harness.model,
        tab: tab,
        document: document,
        split: split,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()
    let view = try #require(host.descendants(of: SplitDiffDocumentView.self).first)

    for (column, y) in [(view.onDisk, 120.0), (view.committed, 260.0), (view.onDisk, 1e6)] {
      column.scroll(to: NSPoint(x: 0, y: y))
      host.layoutSubtreeIfNeeded()
      #expect(view.committed.scrollOrigin.y == view.onDisk.scrollOrigin.y, "scrolled to \(y)")
    }
    #expect(view.onDisk.scrollOrigin.y > 0)
  }

  @Test func noHeaderOrFoldReachesTheVerticalScrollerAtItsWidest() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt", "c.txt"], rows: 60),
      collapsed: [],
      heldOpen: [:],
    )

    let (hosted, window) = Self.hosted(document, in: harness, tab: tab)
    defer { withExtendedLifetime(window) {} }

    let view = try #require(hosted)
    let scrollView = try #require(view.textView.enclosingScrollView)
    let widest = NSScroller.scrollerWidth(for: .regular, scrollerStyle: scrollView.scrollerStyle)
    let scrollerLeft = scrollView.bounds.maxX - widest
    let boxes = view.spanningGapViews.subviews.filter { !$0.isHidden }
    #expect(!boxes.isEmpty)
    for box in boxes {
      #expect(box.convert(box.bounds, to: scrollView).maxX <= scrollerLeft)
    }
  }

  @Test func noSplitHeaderOrFoldReachesTheVerticalScrollerAtItsWidest() throws {
    let harness = ModelHarness()
    let tab = AllChangesTab(worktreeID: "/repos/demo", groupID: UUID())
    let document = AllChangesDocument(
      Self.reading(paths: ["a.txt", "b.txt", "c.txt"], rows: 60),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )
    let split = try #require(document.split)
    let host = NSHostingView(
      rootView: AllChangesSplitDocumentRepresentable(
        model: harness.model,
        tab: tab,
        document: document,
        split: split,
        theme: Theme.builtins[0],
        font: FileFont(family: nil, size: 12),
        find: FindMatchesShown(text: "", matches: [], selected: nil, selectionMoves: 0),
      )
    )
    host.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
    let window = OffscreenWindow.holding(host, deferred: false)
    defer { withExtendedLifetime(window) {} }
    host.layoutSubtreeIfNeeded()

    let view = try #require(host.descendants(of: SplitDiffDocumentView.self).first)
    let scrollView = try #require(view.onDisk.textView.enclosingScrollView)
    let widest = NSScroller.scrollerWidth(for: .regular, scrollerStyle: scrollView.scrollerStyle)
    let scrollerLeft = scrollView.convert(scrollView.bounds, to: view).maxX - widest
    let boxes = view.spanningGapViews.subviews.filter { !$0.isHidden }
    #expect(!boxes.isEmpty)
    for box in boxes {
      #expect(box.convert(box.bounds, to: view).maxX <= scrollerLeft)
    }
  }
}
