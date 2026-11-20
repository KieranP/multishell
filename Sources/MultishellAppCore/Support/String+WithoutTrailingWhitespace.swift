extension String {
  /// The text a selection dragged past its last letter means, as the copy key
  /// trims it; libghostty's read keeps the spaces.
  var withoutTrailingWhitespace: String {
    guard let last = lastIndex(where: { !$0.isWhitespace }) else { return "" }
    return String(self[...last])
  }
}
