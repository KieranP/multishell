/// The find state a file tab's view last drew, kept while a hidden tab drops
/// the view: the rebuilt one moves the selection only past what was drawn.
public struct FileFindShown: Equatable, Sendable {
  public let text: String
  public let selectionMoves: Int

  public init(text: String, selectionMoves: Int) {
    self.text = text
    self.selectionMoves = selectionMoves
  }
}
