import AppKit

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffTextView {
  /// The rows TextKit 2 laid out in the viewport, each against where its
  /// number says it sits.
  var misplacedRows: [String] {
    guard let layoutManager = textLayoutManager,
      let viewport = layoutManager.textViewportLayoutController.viewportRange
    else { return ["no viewport"] }
    layoutManager.ensureLayout(for: viewport)
    var misplaced: [String] = []
    layoutManager.enumerateTextLayoutFragments(from: viewport.location, options: []) { fragment in
      let offset = layoutManager.offset(
        from: layoutManager.documentRange.location,
        to: fragment.rangeInElement.location,
      )
      let row = displayText.row(atOffset: offset)
      let expected = CGFloat(row) * geometry.rowHeight
      if abs(fragment.layoutFragmentFrame.minY - expected) > 0.5 {
        misplaced.append(
          "row \(row) at y \(fragment.layoutFragmentFrame.minY) expected \(expected)"
        )
      }
      return fragment.rangeInElement.location.compare(viewport.endLocation) == .orderedAscending
    }
    return misplaced
  }
}
