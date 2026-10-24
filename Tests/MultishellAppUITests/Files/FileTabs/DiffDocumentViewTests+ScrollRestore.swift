import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffDocumentViewTests {
  @Test func aRebuiltViewReturnsToTheRowItWasLeftAtAndReportsNoneOfIt() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [FileTabScroll] = []
    view.onScrolledTo = { reported.append($0) }
    view.restore(FileTabScroll(line: 0, isCommittedLine: false, rowsFromLine: 120, x: 0))
    view.show(
      DiffDisplayText(DiffDocumentFixture.lines(400), marksStaging: true),
      theme: Theme.builtins[0],
    )
    #expect(reported.isEmpty)

    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollOrigin.y == view.textView.geometry.top(ofRow: 120))
    #expect(reported.isEmpty)
  }

  @Test func aRestoreTakenWhileARereadLaysOutIsNotUndoneByThatReread() {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.restore(FileTabScroll(line: 0, isCommittedLine: false, rowsFromLine: 120, x: 0))
    view.show(DiffDisplayText([], marksStaging: true), theme: Theme.builtins[0])
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    view.show(
      DiffDisplayText(DiffDocumentFixture.lines(400), marksStaging: true),
      theme: Theme.builtins[0],
    )
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollOrigin.y == view.textView.geometry.top(ofRow: 120))
  }

  @Test func aViewLeftAtTheTopComesBackAtTheTopWithItsInset() throws {
    let text = DiffDisplayText(DiffDocumentFixture.lines(400), marksStaging: true)
    let first = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var saved: FileTabScroll?
    first.onScrolledTo = { saved = $0 }
    first.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let firstWindow = OffscreenWindow.holding(first, deferred: false)
    defer { withExtendedLifetime(firstWindow) {} }
    first.show(text, theme: Theme.builtins[0])
    first.layoutSubtreeIfNeeded()

    let second = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    second.restore(try #require(saved))
    second.show(text, theme: Theme.builtins[0])
    second.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let secondWindow = OffscreenWindow.holding(second, deferred: false)
    defer { withExtendedLifetime(secondWindow) {} }
    second.layoutSubtreeIfNeeded()

    #expect(second.scrollOrigin.y == 0)
  }

  @Test func aRereadAfterARestoreReportsTheLineThatIsNowAtTheTop() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    var reported: [FileTabScroll] = []
    view.onScrolledTo = { reported.append($0) }
    view.restore(FileTabScroll(line: 120, isCommittedLine: false, rowsFromLine: 0, x: 0))
    view.show(
      DiffDocumentFixture.contextLines((1...400).map { "line \($0)" }),
      theme: Theme.builtins[0],
    )
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()
    let reRead = DiffDisplayText(
      (1...20).map { (number: Int) in
        DiffLine(kind: .removed, oldNumber: number, newNumber: nil, text: "line \(number)")
      }
        + (21...400).map { (number: Int) in
          DiffLine(
            kind: .context,
            oldNumber: number,
            newNumber: number - 20,
            text: "line \(number)",
          )
        },
      marksStaging: true,
    )

    view.show(reRead, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    #expect(reported.last == reRead.scroll(atRow: view.topRow, x: 0))
  }
}
