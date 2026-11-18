import AppKit

/// Views in the gaps across a diff canvas's columns, the All changes tab's folds
/// and notices; a click reaches what is under it unless it lands on one.
final class SpanningGapViewsLayer: NSView {
  override var isFlipped: Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    return hit === self ? nil : hit
  }
}
