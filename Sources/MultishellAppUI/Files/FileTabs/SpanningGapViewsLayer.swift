import AppKit

/// Over a document's gutter and text, or a split's two columns, holding views
/// that sit in the gaps across them: the All changes tab's headers and folds.
/// Flipped as the text views are, and a click reaches what is under it unless
/// it lands on one of those views.
final class SpanningGapViewsLayer: NSView {
  /// The scroller a wheel over one of its views turns, as it would over the text.
  weak var scrollsWith: NSView?

  override var isFlipped: Bool { true }

  override func scrollWheel(with event: NSEvent) {
    guard let scrollsWith else {
      super.scrollWheel(with: event)
      return
    }
    scrollsWith.scrollWheel(with: event)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    return hit === self ? nil : hit
  }
}
