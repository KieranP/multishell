extension RandomAccessCollection {
  /// Where `belongsAfter` turns from false to true, found by halving;
  /// `endIndex` where it never does. Its answers must run false, then true.
  func partitioningIndex(where belongsAfter: (Element) -> Bool) -> Index {
    var low = startIndex
    var remaining = count
    while remaining > 0 {
      let half = remaining / 2
      let middle = index(low, offsetBy: half)
      if belongsAfter(self[middle]) {
        remaining = half
      } else {
        low = index(after: middle)
        remaining -= half + 1
      }
    }
    return low
  }
}
