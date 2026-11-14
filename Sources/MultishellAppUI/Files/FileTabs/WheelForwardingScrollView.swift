import AppKit

/// A file view's scroller: its clip starts right of the gutter it holds, and
/// it can hand its wheel on, as the All changes tab's view of a file shown whole
/// does to the split around it.
final class WheelForwardingScrollView: NSScrollView {
  weak var forwardsWheelTo: NSView?
  /// The gutter's width, which the clip leaves at its left: the gutter and the
  /// views across it sit inside the scroller, under its scrollers.
  var leadingContentInset: CGFloat = 0 {
    didSet { if leadingContentInset != oldValue { tile() } }
  }
  /// Room the clip leaves at its right for the vertical scroller, which then
  /// sits outside the text and whatever is laid over it.
  var trailingContentInset: CGFloat = 0 {
    didSet { if trailingContentInset != oldValue { tile() } }
  }

  override func tile() {
    super.tile()
    guard leadingContentInset > 0 || trailingContentInset > 0 else { return }
    var frame = contentView.frame
    frame.origin.x += leadingContentInset
    frame.size.width = max(0, frame.width - leadingContentInset - trailingContentInset)
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
