import AppKit

extension NSView {
  /// Sends every scroll view in this view's tree back to its top.
  ///
  /// The whole tree, not the shown tab's scroll view alone, because a tab
  /// switch asked for through SwiftUI state lands after this runs: scrolling
  /// all of them is the same answer whichever tab is up by then, and leaves
  /// the ones behind it as a fresh open would.
  func scrollDescendantsToTop() {
    if let scrollView = self as? NSScrollView, let document = scrollView.documentView {
      let clip = scrollView.contentView
      // The top of a document is not y 0. A scroll view under a toolbar
      // carries a top content inset, so its top is above its own origin,
      // and an unflipped document view counts from the far end of its
      // height instead. Proposing a point past the top and letting AppKit
      // clamp it settles both without spelling either out.
      let beyondTop = document.frame.height + clip.bounds.height
      let proposed = CGRect(
        origin: CGPoint(x: 0, y: document.isFlipped ? -beyondTop : beyondTop),
        size: clip.bounds.size)
      clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
      scrollView.reflectScrolledClipView(clip)
    }
    for subview in subviews { subview.scrollDescendantsToTop() }
  }
}
