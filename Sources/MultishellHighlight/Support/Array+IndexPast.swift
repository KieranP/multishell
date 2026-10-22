extension [UInt16] {
  /// Just past the first `closing` at or after `start`, or the end where none
  /// follows, as an unclosed comment or tag runs to the end of the file.
  func index(past closing: [UInt16], from start: Int) -> Int {
    var index = start
    while index + closing.count <= count {
      if self[index..<(index + closing.count)].elementsEqual(closing) {
        return index + closing.count
      }
      index += 1
    }
    return count
  }
}
