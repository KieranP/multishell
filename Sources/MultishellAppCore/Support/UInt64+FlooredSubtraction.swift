extension UInt64 {
  /// `self - other`, or zero where `other` is larger, which would trap.
  func subtractingFlooredAtZero(_ other: UInt64) -> UInt64 {
    self > other ? self - other : 0
  }
}
