extension DiffDisplayText {
  /// The UTF-16 length of the row's text as shown, a cut line's mark left out:
  /// a colour reaching past it would land on the next row.
  func shownLength(ofRow row: Int) -> Int {
    let length = lines[row].text.utf16.count
    return cutRemainders[row] == nil ? length : length - 1
  }
}
