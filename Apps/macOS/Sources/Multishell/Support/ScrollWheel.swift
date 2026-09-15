import AppKit
import SwiftUI

/// How the two halves of a sideways wheel find each other. SwiftUI flattens
/// the view tree, so the catcher outside a scroller has no way to it: the
/// marker inside hands it over. See docs/design/tabs-and-columns.md.
final class ScrollerHandle {
  weak var scroller: NSScrollView?
}

extension View {
  /// Goes on the content inside the scroller, which is the only place its
  /// own scroller can be named from.
  func marksScroller(_ handle: ScrollerHandle) -> some View {
    background { ScrollerMarker(handle: handle) }
  }

  /// Turns a wheel's vertical scrolling into sideways scrolling of the
  /// marked scroller: a mouse turns one way, and a horizontal scroller is
  /// handed nothing by a plain vertical event. Measured: without this such a
  /// scroller moves by 0.
  ///
  /// Goes outside the scroller, over it. A scroller takes every scroll event
  /// over its own content before a view inside it is offered one, so a
  /// catcher in there is hit-tested and then never called.
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
final class ScrollerMarkerView: NSView {
  var handle: ScrollerHandle? {
    didSet { publish() }
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    setAccessibilityElement(false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

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
/// and a sideways scroll reach what is underneath untouched. What it does
/// take, it hands to the marked scroller with the axes swapped, so the
/// scrolling is AppKit's: the pixels, the momentum and the rubber band.
final class SidewaysWheelView: NSView {
  var handle: ScrollerHandle?

  override init(frame: NSRect) {
    super.init(frame: frame)
    // Not an element of its own, or VoiceOver would read an unlabelled item
    // inside every tab it covers.
    setAccessibilityElement(false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

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

  /// The same event turned on its side. Copied rather than built, so the
  /// phase, the momentum and the precision it arrived with are kept.
  private func sideways(_ event: NSEvent) -> NSEvent? {
    guard let swapped = event.cgEvent?.copy() else { return nil }
    let lines = swapped.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let points = swapped.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
    let fixed = swapped.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
    swapped.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
    swapped.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
    swapped.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
    swapped.setIntegerValueField(
      .scrollWheelEventDeltaAxis2,
      value: swapped.getIntegerValueField(.scrollWheelEventDeltaAxis2) + lines)
    swapped.setDoubleValueField(
      .scrollWheelEventPointDeltaAxis2,
      value: swapped.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) + points)
    swapped.setDoubleValueField(
      .scrollWheelEventFixedPtDeltaAxis2,
      value: swapped.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2) + fixed)
    return NSEvent(cgEvent: swapped)
  }
}
