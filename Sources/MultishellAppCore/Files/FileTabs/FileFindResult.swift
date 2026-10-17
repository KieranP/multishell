import Foundation
import MultishellCore

/// A file tab's search: every match of the find text in its rows, and the one
/// selected. The spikes searched 11,250 lines in 2 to 4 ms.
struct FileFindResult: Equatable, Sendable {
  /// In UTF-16 units of the rows' text, top to bottom.
  private(set) var matches: [Range<Int>]
  /// The first match is selected as the text is set, as a text editor does.
  private(set) var selected: Int?
  /// Counts each step and new search, the only things that move the view's
  /// selection: a re-read can shift `selected` by matches found above it.
  private(set) var selectionMoves = 0
  /// Searched in a split's right side, which a tab hidden through a layout
  /// switch carries its selection from once read again.
  var isSearchedInSplit = false

  var matchCount: FindMatchCount {
    FindMatchCount(position: selected.map { $0 + 1 }, total: matches.count)
  }

  /// Case-insensitive and literal, as the terminal's search is. A search
  /// keeping the selection holds to the match nearest the one selected before.
  static func searching(
    _ text: String,
    in display: DiffDisplayText,
    after previous: Self?,
    keepingSelection: Bool,
  ) -> Self {
    var result = found(text, in: display, keepingSelectionOf: keepingSelection ? previous : nil)
    result.selectionMoves = (previous?.selectionMoves ?? 0) + (keepingSelection ? 0 : 1)
    return result
  }

  /// A new search on a tab whose rows are not yet back: no matches, but the
  /// move counted, so the read that brings them selects and scrolls.
  static func awaitingRows(after previous: Self?) -> Self {
    var result = Self(matches: [], selected: nil)
    result.selectionMoves = (previous?.selectionMoves ?? 0) + 1
    return result
  }

  private static func found(
    _ text: String,
    in display: DiffDisplayText,
    keepingSelectionOf previous: Self?,
  ) -> Self {
    guard !text.isEmpty else { return Self(matches: [], selected: nil) }
    let searchedText = display.string as NSString
    var matches: [Range<Int>] = []
    var from = 0
    while from < searchedText.length {
      let found = searchedText.range(
        of: text,
        options: [.caseInsensitive],
        range: NSRange(location: from, length: searchedText.length - from),
      )
      guard found.location != NSNotFound, found.length > 0 else { break }
      matches.append(found.location..<NSMaxRange(found))
      from = NSMaxRange(found)
    }
    guard !matches.isEmpty else { return Self(matches: [], selected: nil) }
    guard let previous, let old = previous.selected, previous.matches.indices.contains(old) else {
      return Self(matches: matches, selected: 0)
    }
    let oldStart = previous.matches[old].lowerBound
    let nearest = matches.indices.min { first, second in
      abs(matches[first].lowerBound - oldStart) < abs(matches[second].lowerBound - oldStart)
    }
    return Self(matches: matches, selected: nearest)
  }

  /// The selected match carried onto another layout of the same rows, its
  /// offset meaning nothing there; `nil` selected where its line's text differs.
  func carried(from old: DiffDisplayText, to new: DiffDisplayText) -> Self {
    var carried = self
    let match = selected.flatMap { matches.indices.contains($0) ? matches[$0] : nil }
    let moved = match.flatMap { new.rangeOnSameLine($0, from: old) }
    carried.matches = moved.map { [$0] } ?? []
    carried.selected = moved == nil ? nil : 0
    return carried
  }

  /// Wraps at either end.
  mutating func step(_ direction: CycleDirection) {
    guard !matches.isEmpty else { return }
    selectionMoves += 1
    guard let selected else {
      self.selected = direction == .next ? 0 : matches.count - 1
      return
    }
    let step = direction == .next ? 1 : matches.count - 1
    self.selected = (selected + step) % matches.count
  }
}
