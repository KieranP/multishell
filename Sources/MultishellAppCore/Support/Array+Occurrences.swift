extension Array {
  /// Every index where `pattern` starts, overlapping ones included, in one pass
  /// (Knuth-Morris-Pratt): a start-by-start scan of a repeated line took 20 s.
  func startsOfOccurrences(
    of pattern: [Element],
    by isSame: (Element, Element) -> Bool,
  ) -> [Int] {
    guard !pattern.isEmpty, pattern.count <= count else { return [] }
    var borders = [Int](repeating: 0, count: pattern.count)
    var length = 0
    for index in pattern.indices.dropFirst() {
      while length > 0, !isSame(pattern[index], pattern[length]) { length = borders[length - 1] }
      if isSame(pattern[index], pattern[length]) { length += 1 }
      borders[index] = length
    }
    var starts: [Int] = []
    length = 0
    for index in indices {
      while length > 0, !isSame(self[index], pattern[length]) { length = borders[length - 1] }
      if isSame(self[index], pattern[length]) { length += 1 }
      if length == pattern.count {
        starts.append(index - length + 1)
        length = borders[length - 1]
      }
    }
    return starts
  }
}
