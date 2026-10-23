extension [Range<Int>] {
  /// In ranges whose ends ascend, the first ending after `offset`; `count`
  /// where none does.
  public func firstIndex(endingAfter offset: Int) -> Int {
    partitioningIndex { $0.upperBound > offset }
  }
}
