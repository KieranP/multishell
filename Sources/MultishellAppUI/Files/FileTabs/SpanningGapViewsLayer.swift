import AppKit

/// On a diff canvas over the columns, holding views that sit in the gaps across
/// them: the All changes tab's headers, folds and file boxes. Flipped as the
/// canvas is, and a click reaches what is under it unless it lands on one of
/// those views.
final class SpanningGapViewsLayer: NSView {
  override var isFlipped: Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    return hit === self ? nil : hit
  }
}
