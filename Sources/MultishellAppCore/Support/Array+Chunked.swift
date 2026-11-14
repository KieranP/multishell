extension Array {
  /// Consecutive runs of `size` elements in order, the last possibly shorter.
  func chunked(into size: Int) -> [ArraySlice<Element>] {
    stride(from: 0, to: count, by: size).map { self[$0..<Swift.min($0 + size, count)] }
  }
}
