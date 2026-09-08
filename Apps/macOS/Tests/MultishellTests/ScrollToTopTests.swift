import AppKit
import Testing

@testable import Multishell

@Suite @MainActor
struct ScrollToTopTests {
  /// A 100 pt scroll view holding a document taller than itself, scrolled
  /// away from the top.
  private func scrolledAway(
    flipped: Bool, topInset: CGFloat = 0, documentHeight: CGFloat = 400
  )
    -> NSScrollView
  {
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let document = flipped ? FlippedView() : NSView()
    document.frame = CGRect(x: 0, y: 0, width: 100, height: documentHeight)
    scrollView.documentView = document
    scrollView.automaticallyAdjustsContentInsets = false
    scrollView.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
    scrollView.contentView.scroll(to: CGPoint(x: 0, y: flipped ? 150 : 40))
    return scrollView
  }

  @Test func aFlippedDocumentGoesBackToTheTop() {
    let scrollView = scrolledAway(flipped: true)
    #expect(scrollView.contentView.bounds.origin.y != 0)
    scrollView.scrollDescendantsToTop()
    #expect(scrollView.contentView.bounds.origin.y == 0)
  }

  /// The regression: a settings window's toolbar gives its scroll view a top
  /// content inset, and the top of the document is that far above y 0. Going
  /// to 0 instead hid the first rows under the toolbar.
  @Test func aTopContentInsetIsTheTop() {
    let scrollView = scrolledAway(flipped: true, topInset: 52)
    scrollView.scrollDescendantsToTop()
    #expect(scrollView.contentView.bounds.origin.y == -52)
  }

  /// Content shorter than the window still sits under the inset, not over it.
  @Test func aDocumentShorterThanItsScrollViewKeepsTheInset() {
    let scrollView = scrolledAway(flipped: true, topInset: 52, documentHeight: 50)
    scrollView.scrollDescendantsToTop()
    #expect(scrollView.contentView.bounds.origin.y == -52)
  }

  /// An unflipped document's top is the far end of its height, not zero.
  @Test func anUnflippedDocumentGoesBackToTheTop() {
    let scrollView = scrolledAway(flipped: false)
    scrollView.scrollDescendantsToTop()
    #expect(scrollView.contentView.bounds.origin.y == 300)
  }

  @Test func anUnflippedDocumentUnderAnInsetGoesBackToTheTop() {
    let scrollView = scrolledAway(flipped: false, topInset: 52)
    scrollView.scrollDescendantsToTop()
    #expect(scrollView.contentView.bounds.origin.y == 352)
  }

  @Test func aScrollViewNestedInAnotherIsScrolledToo() {
    let outer = scrolledAway(flipped: true)
    let inner = scrolledAway(flipped: true)
    outer.documentView?.addSubview(inner)

    outer.scrollDescendantsToTop()

    #expect(outer.contentView.bounds.origin.y == 0)
    #expect(inner.contentView.bounds.origin.y == 0, "a tab's own scroll view sits inside the form")
  }

  /// The window's whole tree is walked, so a scroll view anywhere under a
  /// plain container is still found.
  @Test func aScrollViewUnderAPlainViewIsFound() {
    let container = NSView()
    let scrollView = scrolledAway(flipped: true)
    container.addSubview(NSView())
    container.subviews[0].addSubview(scrollView)

    container.scrollDescendantsToTop()

    #expect(scrollView.contentView.bounds.origin.y == 0)
  }

  @Test func aScrollViewWithNoDocumentIsLeftAlone() {
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    scrollView.scrollDescendantsToTop()
  }

  private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
  }
}
