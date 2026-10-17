import AppKit
import MultishellAppCore

/// The find bar's matches painted under the text with the line tints; see
/// files.md for why not as TextKit 2 rendering attributes.
extension DiffTextView {
  /// Matches in UTF-16 units; the selected one is scrolled to where `find` moved
  /// it since `previous`, else selected alone on a rebuilt view's first paint.
  func showFindMatches(
    _ find: FindMatchesShown,
    after previous: FindMatchesShown?,
    isFirstPaint: Bool,
    tint: NSColor,
  ) {
    let matches = find.matches
    findMatchPaint = (matches, tint)
    needsDisplay = true
    guard let selected = find.selected, matches.indices.contains(selected) else { return }
    let match = matches[selected]
    let range = NSRange(location: match.lowerBound, length: match.count)
    if find.movesSelection(from: previous) {
      setSelectedRange(range)
      scrollRangeToVisible(range)
    } else if isFirstPaint {
      setSelectedRange(range)
    }
  }

  /// Only the matches on the rows `rect` reaches, found by halving.
  func drawFindMatches(in rect: NSRect) {
    let (matches, tint) = findMatchPaint
    let rows = geometry.rows(in: rect, count: displayText.lines.count)
    guard !matches.isEmpty, !rows.isEmpty, let layoutManager = textLayoutManager
    else { return }
    let shownStart = displayText.rowStarts[rows.lowerBound]
    let shownEnd = displayText.range(ofRow: rows.upperBound - 1).upperBound
    var low = 0
    var high = matches.count
    while low < high {
      let middle = (low + high) / 2
      if matches[middle].upperBound <= shownStart { low = middle + 1 } else { high = middle }
    }
    tint.setFill()
    for match in matches[low...] {
      guard match.lowerBound < shownEnd else { break }
      fillTextSegments(of: match, layoutManager: layoutManager)
    }
  }
}
