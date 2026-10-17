/// The find bar's matches as a file tab's view last drew them: a re-read
/// repaints them, and only a new find text or step moves the selection.
struct FindMatchesShown: Equatable {
  let text: String
  let matches: [Range<Int>]
  let selected: Int?
  let selectionMoves: Int

  /// A save under the bar keeps the user's scroll and selection.
  func movesSelection(from previous: Self?) -> Bool {
    previous?.text != text || previous?.selectionMoves != selectionMoves
  }
}
