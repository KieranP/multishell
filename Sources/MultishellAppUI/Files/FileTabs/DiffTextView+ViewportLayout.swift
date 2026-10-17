import AppKit
import MultishellAppCore

extension DiffTextView {
  /// TextKit lays out every row from its estimated top to a far jump's forced
  /// one; rows laid out first, a screen either side, stop that walk.
  func layOutRowsAroundView() {
    let visible = visibleRect
    guard !isReplacingText, !visible.isEmpty, let layoutManager = textLayoutManager else {
      return
    }
    let rows = geometry.rows(
      in: visible.insetBy(dx: 0, dy: -visible.height),
      count: displayText.lines.count,
    )
    guard let first = rows.first, let last = rows.last else { return }
    let units =
      displayText.range(ofRow: first).lowerBound..<displayText.range(ofRow: last).upperBound
    if let range = textRange(of: units, in: layoutManager) {
      layoutManager.ensureLayout(for: range)
    }
  }
}
