extension Array {
  /// Consecutive runs of `size` elements in order, the last possibly shorter.
  public func chunked(into size: Int) -> [[Element]] {
    stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
  }
}
