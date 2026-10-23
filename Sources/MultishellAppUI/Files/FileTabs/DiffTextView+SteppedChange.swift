import AppKit

/// A box around the change the bar's last step landed on, so with several
/// changes in view it shows which one the next step counts from.
extension DiffTextView {
  private static let steppedChangeLineWidth: CGFloat = 1.5

  /// Across the visible width, not the document's, so all four sides show.
  func drawSteppedChange() {
    guard let rect = rect(ofSteppedChange: steppedChange) else { return }
    steppedChangeBorder.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
    path.lineWidth = Self.steppedChangeLineWidth
    path.stroke()
  }

  /// A sideways scroll moves the box's sides, which the copied pixels would
  /// otherwise leave where they were; a change of box repaints both.
  func redraw(steppedChange rows: Range<Int>?) {
    guard let rect = rect(ofSteppedChange: rows) else { return }
    let outset = -Self.steppedChangeLineWidth
    setNeedsDisplay(rect.insetBy(dx: outset, dy: outset))
  }

  private func rect(ofSteppedChange rows: Range<Int>?) -> NSRect? {
    guard let rows, !rows.isEmpty else { return nil }
    let inset = Self.steppedChangeLineWidth
    return NSRect(
      x: visibleRect.minX + inset,
      y: geometry.top(ofRow: rows.lowerBound) + inset / 2,
      width: max(0, visibleRect.width - inset * 2),
      height: CGFloat(rows.count) * geometry.rowHeight - inset,
    )
  }
}
