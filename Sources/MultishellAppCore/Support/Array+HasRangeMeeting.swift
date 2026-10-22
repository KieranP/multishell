extension [Range<Int>] {
  /// In ranges whose ends ascend, whether one overlaps `range` or holds an empty one
  /// strictly inside it.
  public func hasRange(meeting range: Range<Int>) -> Bool {
    let index = firstIndex(endingAfter: range.lowerBound)
    return index < count && self[index].lowerBound < range.upperBound
  }
}
