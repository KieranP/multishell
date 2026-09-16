extension Comparable {
  /// Traps where the range is empty, which every caller rules out first.
  public func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
