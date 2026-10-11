extension Array {
  /// The newest `count`, oldest first, for a log or history held to a size.
  mutating func keepLast(_ count: Int) {
    if self.count > count { removeFirst(self.count - count) }
  }
}
