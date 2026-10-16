import MultishellAppCore

/// To and from the model's record of what a dropped view drew.
extension FindMatchesShown {
  var shown: FileFindShown {
    FileFindShown(text: text, selectionMoves: selectionMoves)
  }

  /// No matches: only the text and the count decide whether a selection moves.
  init(_ shown: FileFindShown) {
    self.init(text: shown.text, matches: [], selected: nil, selectionMoves: shown.selectionMoves)
  }
}
