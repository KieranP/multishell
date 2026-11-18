import AppKit
import MultishellGitKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct AllChangesFileViewTests {
  @Test func aViewKeptForAnotherFileOfTheSameHeightStillReportsItsHeight() {
    let lines = (1...4).map { (number: Int) in
      DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: "\(number)")
    }
    let file = AllChangesFile(
      change: AllChangesFileChange(path: "a.txt", kind: .added, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(FileTabRows(lines: lines, marksStaging: true)),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
    let document = AllChangesDocument(
      AllChangesReading(listed: [file.change], files: [file]),
      collapsed: [],
      heldOpen: [:],
    )
    let slice = document.slice(ofSection: 0)
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: false,
      scrollsWith: nil,
    )
    let show = {
      view.show(
        slice,
        header: .sample(of: document),
        item: { _, _ in AnyView(EmptyView()) },
        itemHeight: { _ in 0 },
        theme: Theme.builtins[0],
      )
    }
    _ = show()
    var reported = 0
    view.onHeightChanged = { reported += 1 }

    view.forgetShownFile()
    _ = show()

    #expect(reported > 0)
  }

  @Test func aViewKeptForAnotherFileOpensNoneOfTheLastFilesCardGaps() {
    let lines = (1...4).map { (number: Int) in
      DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: "\(number)")
    }
    let file = AllChangesFile(
      change: AllChangesFileChange(path: "a.txt", kind: .added, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(FileTabRows(lines: lines, marksStaging: true)),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
    let document = AllChangesDocument(
      AllChangesReading(listed: [file.change], files: [file]),
      collapsed: [],
      heldOpen: [:],
    )
    let slice = document.slice(ofSection: 0)
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: false,
      scrollsWith: nil,
    )
    let show = {
      _ = view.show(
        slice,
        header: .sample(of: document),
        item: { _, _ in AnyView(EmptyView()) },
        itemHeight: { _ in 0 },
        theme: Theme.builtins[0],
      )
    }
    show()
    let plain = view.height
    view.unified?.onReviewCardGaps?([1: 40])

    view.forgetShownFile()
    show()

    #expect(view.height == plain)
  }

  @Test func aWideFileShowsItsLastRowWithScrollBarsAlwaysShown() {
    let file = AllChangesFile(
      change: AllChangesFileChange(path: "a.txt", kind: .added, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(
            FileTabRows(
              lines: [
                DiffLine(
                  kind: .added,
                  oldNumber: nil,
                  newNumber: 1,
                  text: String(repeating: "x", count: 400),
                )
              ],
              marksStaging: true,
            )
          ),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
    let document = AllChangesDocument(
      AllChangesReading(listed: [file.change], files: [file]),
      collapsed: [],
      heldOpen: [:],
    )
    let slice = document.slice(ofSection: 0)
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: false,
      scrollsWith: nil,
    )
    view.canvas.scrollView.scrollerStyle = .legacy
    _ = view.show(
      slice,
      header: .sample(of: document),
      item: { _, _ in AnyView(EmptyView()) },
      itemHeight: { _ in 0 },
      theme: Theme.builtins[0],
    )
    view.frame = NSRect(x: 0, y: 0, width: 300, height: view.height)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    #expect(view.canvas.clipHeight >= view.height - AllChangesFileView.headerHeight)
  }

  @Test func aSplitViewLetGoOfWhileScrolledSidewaysAsksTheListForNoLayout() {
    let wide = String(repeating: "x", count: 400)
    let file = AllChangesFile(
      change: AllChangesFileChange(path: "a.txt", kind: .modified, lineCounts: nil),
      content: .read(
        FileTabReading(
          content: .text(
            FileTabRows(
              lines: [
                DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: wide),
                DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: wide + "y"),
              ],
              marksStaging: true,
            )
          ),
          isFileGone: false,
        )
      ),
      signature: nil,
    )
    let document = AllChangesDocument(
      AllChangesReading(listed: [file.change], files: [file]),
      collapsed: [],
      heldOpen: [:],
      layout: .split,
    )
    let slice = document.slice(ofSection: 0)
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: true,
      scrollsWith: nil,
    )
    _ = view.show(
      slice,
      header: .sample(of: document),
      item: { _, _ in AnyView(EmptyView()) },
      itemHeight: { _ in 0 },
      theme: Theme.builtins[0],
    )
    view.frame = NSRect(x: 0, y: 0, width: 300, height: view.height)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()
    view.canvas.scroll(to: NSPoint(x: 100, y: 0))
    var reported = 0
    view.onHeightChanged = { reported += 1 }

    view.forgetShownFile()

    #expect(reported == 0)
  }

  @Test func aViewKeptForAnotherFileCarriesNoRevealTheLastFileWaitedOn() {
    let view = AllChangesFileView(
      geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12),
      isSplit: false,
      scrollsWith: nil,
    )
    view.mainColumn.pendingCardReveal = .comment(UUID())
    view.mainColumn.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    view.mainColumn.restore(FileTabScroll(line: 1, isCommittedLine: false, rowsFromLine: 0, x: 0))

    view.forgetShownFile()

    #expect(!view.mainColumn.hasPendingRestore)
    #expect(view.mainColumn.pendingVisibleRect == nil)
    #expect(view.mainColumn.pendingCardReveal == nil)
  }
}
