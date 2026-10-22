extension [Range<Int>] {
  /// In ranges whose ends ascend, the first ending after `offset`, found by halving;
  /// `count` where none does.
  public func firstIndex(endingAfter offset: Int) -> Int {
    var low = 0
    var high = count
    while low < high {
      let middle = (low + high) / 2
      if self[middle].upperBound <= offset { low = middle + 1 } else { high = middle }
    }
    return low
  }
}
