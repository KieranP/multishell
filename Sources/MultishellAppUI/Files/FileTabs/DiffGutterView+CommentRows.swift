import AppKit
import MultishellAppCore
import MultishellCore

extension DiffGutterView {
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas { removeTrackingArea(area) }
    addTrackingArea(
      NSTrackingArea(
        rect: .zero,
        options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
        owner: self,
      )
    )
  }

  override func mouseMoved(with event: NSEvent) {
    hoveredRow = commentableRow(at: event)
  }

  override func mouseExited(with event: NSEvent) {
    hoveredRow = nil
  }

  /// On the + alone, so a click on a line number does not open a composer.
  override func mouseDown(with event: NSEvent) {
    guard convert(event.locationInWindow, from: nil).x < plusColumnWidth,
      let row = commentableRow(at: event)
    else { return }
    draggedRows = (row, row)
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = draggedRows?.start, let row = row(at: event) else { return }
    draggedRows = (start, row)
  }

  override func mouseUp(with event: NSEvent) {
    guard let dragged = draggedRows else { return }
    draggedRows = nil
    onCommentOnRows?(dragged.start, dragged.end)
  }

  /// The + on the hovered row, and a drag's rows washed in the selection.
  func drawCommentMarks(onRow row: Int, top: CGFloat) {
    if let dragged = draggedRows,
      (min(dragged.start, dragged.end)...max(dragged.start, dragged.end)).contains(row)
    {
      commentColors.dragged.setFill()
      NSRect(x: 0, y: top, width: bounds.width, height: geometry.rowHeight).fill()
    }
    guard row == hoveredRow, draggedRows == nil else { return }
    let side = plusColumnWidth - 4
    let box = NSRect(x: 2, y: top + 2, width: side, height: side)
    commentColors.mark.setFill()
    NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3).fill()
    commentColors.plus.setStroke()
    let plus = NSBezierPath()
    plus.lineWidth = 1.5
    plus.move(to: NSPoint(x: box.midX, y: box.minY + 3))
    plus.line(to: NSPoint(x: box.midX, y: box.maxY - 3))
    plus.move(to: NSPoint(x: box.minX + 3, y: box.midY))
    plus.line(to: NSPoint(x: box.maxX - 3, y: box.midY))
    plus.stroke()
  }

  /// The row under the pointer, `nil` in a card's gap or past the last row.
  private func row(at event: NSEvent) -> Int? {
    let y = convert(event.locationInWindow, from: nil).y + scrolledTo
    let row = Int(geometry.topRow(atScrollOffset: y))
    let top = geometry.top(ofRow: row)
    guard displayText.lines.indices.contains(row), y >= top, y < top + geometry.rowHeight
    else { return nil }
    return row
  }

  /// A row a comment can go on, by the rule a click there would use.
  private func commentableRow(at event: NSEvent) -> Int? {
    guard let row = row(at: event),
      ReviewLineSelection(from: row, to: row, in: displayText.lines, side: commentSide) != nil
    else { return nil }
    return row
  }
}
