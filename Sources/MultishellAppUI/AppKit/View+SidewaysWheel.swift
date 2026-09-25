import SwiftUI

extension View {
  /// Goes on the content inside the scroller, which is the only place its
  /// own scroller can be named from.
  func marksScroller(_ reference: ScrollerReference) -> some View {
    background { ScrollerMarker(reference: reference) }
  }

  /// Turns a wheel's vertical scrolling sideways for the marked scroller. Goes
  /// outside the scroller, over it; see Docs/design/tabs-and-columns.md.
  func wheelScrollsSideways(_ reference: ScrollerReference) -> some View {
    overlay { SidewaysWheel(reference: reference) }
  }
}

private struct ScrollerMarker: NSViewRepresentable {
  let reference: ScrollerReference

  func makeNSView(context: Context) -> ScrollerMarkerView { ScrollerMarkerView() }

  func updateNSView(_ view: ScrollerMarkerView, context: Context) { view.reference = reference }
}

/// Nothing is drawn or clicked here: it is in the scroller's content to say
/// where the scroller is, and takes no part in an event.
private final class ScrollerMarkerView: UnspokenView {
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

private struct SidewaysWheel: NSViewRepresentable {
  let reference: ScrollerReference

  func makeNSView(context: Context) -> SidewaysWheelView { SidewaysWheelView() }

  func updateNSView(_ view: SidewaysWheelView, context: Context) { view.reference = reference }
}
