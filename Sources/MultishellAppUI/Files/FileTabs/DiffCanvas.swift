import AppKit

/// A `DiffCanvasView`'s document: the columns and the gap views, top down by
/// the rows' offsets.
final class DiffCanvas: NSView {
  override var isFlipped: Bool { true }
}
