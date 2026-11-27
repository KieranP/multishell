import AppKit

extension NSView {
  /// Sends every scroll view in this view's tree back to its top. The whole
  /// tree, a tab switch through SwiftUI state landing after this runs.
  func scrollDescendantsToTop() {
    if let scrollView = self as? NSScrollView, let document = scrollView.documentView {
      // The top of a document is not y 0: a content inset and an unflipped
      // document view each move it. Propose past it and let AppKit clamp.
      let beyondTop = document.frame.height + scrollView.contentView.bounds.height
      scrollView.scrollClamped(to: CGPoint(x: 0, y: document.isFlipped ? -beyondTop : beyondTop))
    }
    for subview in subviews { subview.scrollDescendantsToTop() }
  }
}
