/// To and from the model's record of what a dropped view drew.
extension FindMatchesShown {
  public var shown: FileFindShown {
    FileFindShown(text: text, selectionMoves: selectionMoves)
  }

  /// No matches: only the text and the count decide whether a selection moves.
  public init(_ shown: FileFindShown) {
    self.init(text: shown.text, matches: [], selected: nil, selectionMoves: shown.selectionMoves)
  }
}
