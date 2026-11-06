import MultishellAppCore

extension Range<Int> {
  /// The non-empty pieces of this range outside `ranges`, which ascend and do not overlap.
  func subtracting(_ ranges: [Range<Int>]) -> [Range<Int>] {
    var pieces: [Range<Int>] = []
    var start = lowerBound
    var index = ranges.firstIndex(endingAfter: lowerBound)
    while index < ranges.count, ranges[index].lowerBound < upperBound {
      if start < ranges[index].lowerBound { pieces.append(start..<ranges[index].lowerBound) }
      start = Swift.max(start, ranges[index].upperBound)
      index += 1
    }
    if start < upperBound { pieces.append(start..<upperBound) }
    return pieces
  }
}
