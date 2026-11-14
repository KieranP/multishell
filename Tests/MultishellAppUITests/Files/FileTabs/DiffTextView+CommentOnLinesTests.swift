import AppKit
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffTextViewCommentOnLinesTests {
  private static func menuTitles(of textView: DiffTextView, in window: NSWindow) throws -> [String]
  {
    let event = try #require(
      NSEvent.mouseEvent(
        with: .rightMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1,
      )
    )
    return textView.menu(for: event)?.items.map(\.title) ?? []
  }

  @Test func paddingInASplitsLeftColumnOffersNoComment() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.column.commentSide = .committed
    view.onCommentOnLines = { _ in }
    view.show(
      DiffDisplayText([.padding, .padding], marksStaging: true),
      theme: Theme.builtins[0],
    )
    view.layoutSubtreeIfNeeded()
    view.textView.setSelectedRange(NSRange(location: 0, length: 0))

    let titles = try Self.menuTitles(of: view.textView, in: window)

    #expect(!titles.contains(MultishellAppUI.t("review.comment-on-lines")))
  }

  @Test func aLineOfTheColumnsSideOffersAComment() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: ["a", "b"])
    defer { withExtendedLifetime(window) {} }
    view.onCommentOnLines = { _ in }
    view.textView.setSelectedRange(NSRange(location: 0, length: 0))

    let titles = try Self.menuTitles(of: view.textView, in: window)

    #expect(titles.contains(MultishellAppUI.t("review.comment-on-lines")))
  }

  @Test func askingForTheMenuAgainOffersCommentOnLinesOnce() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: ["a", "b"])
    defer { withExtendedLifetime(window) {} }
    view.onCommentOnLines = { _ in }
    view.textView.setSelectedRange(NSRange(location: 0, length: 0))
    _ = try Self.menuTitles(of: view.textView, in: window)

    let titles = try Self.menuTitles(of: view.textView, in: window)

    #expect(titles.count { $0 == MultishellAppUI.t("review.comment-on-lines") } == 1)
  }
}
