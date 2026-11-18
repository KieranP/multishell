import AppKit

/// A diff canvas's scroller, which can leave room for the vertical scroller and
/// hand its vertical wheel on, as an All changes file does to the list.
final class WheelForwardingScrollView: NSScrollView {
  /// A file as tall as its rows bouncing vertically under a sideways swipe jolted it.
  weak var forwardsWheelTo: NSView? {
    didSet { verticalScrollElasticity = forwardsWheelTo == nil ? .automatic : .none }
  }
  /// Overlay scrollers whatever the system setting: inside another scroller's
  /// content, sized to its rows, a legacy one would cover its last row.
  var keepsOverlayScrollers = false {
    didSet { if keepsOverlayScrollers { scrollerStyle = .overlay } }
  }
  private var axisLock = WheelAxisLock()

  override var scrollerStyle: NSScroller.Style {
    get { super.scrollerStyle }
    set { super.scrollerStyle = keepsOverlayScrollers ? .overlay : newValue }
  }
  /// Room the clip leaves at its right for the vertical scroller, which then
  /// sits outside the text and whatever is laid over it.
  var trailingContentInset: CGFloat = 0 {
    didSet { if trailingContentInset != oldValue { tile() } }
  }

  /// The inset counts from the scroller's edge: a legacy scroller's width,
  /// which `super` already took, is part of it.
  override func tile() {
    super.tile()
    guard trailingContentInset > 0 else { return }
    var frame = contentView.frame
    frame.size.width = max(0, min(frame.width, bounds.width - trailingContentInset - frame.minX))
    contentView.frame = frame
  }

  /// A gesture mostly sideways stays here, so a file in the All changes list
  /// scrolls sideways on its own; the rest turns `forwardsWheelTo`.
  override func scrollWheel(with event: NSEvent) {
    guard let forwardsWheelTo,
      axisLock.isVertical(
        dx: event.scrollingDeltaX,
        dy: event.scrollingDeltaY,
        phase: event.phase,
        momentumPhase: event.momentumPhase,
      )
    else {
      super.scrollWheel(with: event)
      return
    }
    forwardsWheelTo.scrollWheel(with: event)
  }
}
