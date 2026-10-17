/// The find bar's matches as a file tab's view last drew them: a re-read
/// repaints them, and only a new find text or step moves the selection.
public struct FindMatchesShown: Equatable {
  let text: String
  public let matches: [Range<Int>]
  public let selected: Int?
  let selectionMoves: Int

  public init(text: String, matches: [Range<Int>], selected: Int?, selectionMoves: Int) {
    self.text = text
    self.matches = matches
    self.selected = selected
    self.selectionMoves = selectionMoves
  }

  /// A save under the bar keeps the user's scroll and selection.
  public func movesSelection(from previous: Self?) -> Bool {
    previous?.text != text || previous?.selectionMoves != selectionMoves
  }
}
