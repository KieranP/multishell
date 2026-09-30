import AppKit

/// Nothing is drawn or clicked here: it is in the scroller's content to say
/// where the scroller is, and takes no part in an event.
final class ScrollerMarkerView: AccessibilityHiddenView {
  var reference: ScrollerReference? {
    didSet { publish() }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    publish()
  }

  private func publish() {
    guard let found = enclosingScrollView else { return }
    reference?.scroller = found
  }
}
