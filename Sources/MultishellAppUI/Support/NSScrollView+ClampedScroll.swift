import AppKit

/// A scroll held within the document's ends, the scrollers moved with it.
extension NSScrollView {
  /// Where `origin` lands once the clip's bounds hold it.
  func clamped(_ origin: NSPoint) -> NSPoint {
    contentView.constrainBoundsRect(NSRect(origin: origin, size: contentView.bounds.size)).origin
  }

  func scrollClamped(to origin: NSPoint) {
    let target = clamped(origin)
    guard contentView.bounds.origin != target else { return }
    contentView.scroll(to: target)
    reflectScrolledClipView(contentView)
  }
}
