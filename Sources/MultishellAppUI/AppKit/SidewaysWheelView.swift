import AppKit

/// Answers `hitTest` only while a vertical scroll is routed, so clicks, drags
/// and a sideways scroll reach what is underneath untouched.
final class SidewaysWheelView: AccessibilityHiddenView {
  var reference: ScrollerReference?

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let event = NSApp.currentEvent, isVertical(event) else { return nil }
    return super.hitTest(point)
  }

  override func scrollWheel(with event: NSEvent) {
    guard let scroller = reference?.scroller else { return super.scrollWheel(with: event) }
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
