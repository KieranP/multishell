import AppKit
import SwiftUI

/// How the two halves of a sideways wheel find each other; SwiftUI flattens
/// the tree, so the catcher cannot look. See Docs/design/tabs-and-columns.md.
final class ScrollerHandle {
  weak var scroller: NSScrollView?
}

extension View {
  /// Goes on the content inside the scroller, which is the only place its
  /// own scroller can be named from.
  func marksScroller(_ handle: ScrollerHandle) -> some View {
    background { ScrollerMarker(handle: handle) }
  }

  /// Turns a wheel's vertical scrolling sideways for the marked scroller. Goes
  /// outside the scroller, over it; see Docs/design/tabs-and-columns.md.
  func wheelScrollsSideways(_ handle: ScrollerHandle) -> some View {
    overlay { SidewaysWheel(handle: handle) }
  }
}

private struct ScrollerMarker: NSViewRepresentable {
  let handle: ScrollerHandle

  func makeNSView(context: Context) -> ScrollerMarkerView { ScrollerMarkerView() }

  func updateNSView(_ view: ScrollerMarkerView, context: Context) { view.handle = handle }
}

/// Nothing is drawn or clicked here: it is in the scroller's content to say
/// where the scroller is, and takes no part in an event.
final class ScrollerMarkerView: UnspokenView {
  var handle: ScrollerHandle? {
    didSet { publish() }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    publish()
  }

  private func publish() {
    guard let found = enclosingScrollView else { return }
    handle?.scroller = found
  }
}

struct SidewaysWheel: NSViewRepresentable {
  let handle: ScrollerHandle

  func makeNSView(context: Context) -> SidewaysWheelView { SidewaysWheelView() }

  func updateNSView(_ view: SidewaysWheelView, context: Context) { view.handle = handle }
}

/// Answers `hitTest` only while a vertical scroll is routed, so clicks, drags
/// and a sideways scroll reach what is underneath untouched.
final class SidewaysWheelView: UnspokenView {
  var handle: ScrollerHandle?

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let event = NSApp.currentEvent, isVertical(event) else { return nil }
    return super.hitTest(point)
  }

  override func scrollWheel(with event: NSEvent) {
    guard let scroller = handle?.scroller else { return super.scrollWheel(with: event) }
    // A turn that goes sideways partway through can still arrive here, the
    // view a scroll is routed to being the one its first event hit.
    scroller.scrollWheel(with: isVertical(event) ? sideways(event) ?? event : event)
  }

  private func isVertical(_ event: NSEvent) -> Bool {
    event.type == .scrollWheel && abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)
  }

  /// The same event turned on its side, copied so phase and precision are
  /// kept. Each field is written once, lines first: they are coupled, see the doc.
  private func sideways(_ event: NSEvent) -> NSEvent? {
    guard let swapped = event.cgEvent?.copy() else { return nil }
    let lines = swapped.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let points = swapped.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
    let fixed = swapped.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
    swapped.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
    swapped.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
    swapped.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
    swapped.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: lines)
    swapped.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: points)
    swapped.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed)
    return NSEvent(cgEvent: swapped)
  }
}
