import AppKit

/// A diff canvas's scroller: its clip can leave room at its right for the
/// vertical scroller, and it can hand its wheel on, as the All changes tab's
/// view of a file shown whole does to the split around it.
final class WheelForwardingScrollView: NSScrollView {
  weak var forwardsWheelTo: NSView?
  /// Room the clip leaves at its right for the vertical scroller, which then
  /// sits outside the text and whatever is laid over it.
  var trailingContentInset: CGFloat = 0 {
    didSet { if trailingContentInset != oldValue { tile() } }
  }

  override func tile() {
    super.tile()
    guard trailingContentInset > 0 else { return }
    var frame = contentView.frame
    frame.size.width = max(0, frame.width - trailingContentInset)
    contentView.frame = frame
  }

  override func scrollWheel(with event: NSEvent) {
    guard let forwardsWheelTo else {
      super.scrollWheel(with: event)
      return
    }
    forwardsWheelTo.scrollWheel(with: event)
  }
}
