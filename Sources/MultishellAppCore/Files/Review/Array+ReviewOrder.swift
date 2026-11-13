import MultishellCore

extension [ReviewComment] {
  /// By path, then line, removed lines before the added ones that replaced them,
  /// as Review lists them and Send writes them.
  var inReviewOrder: [ReviewComment] {
    sorted { left, right in
      if left.path != right.path { return left.path < right.path }
      if left.lines.lowerBound != right.lines.lowerBound {
        return left.lines.lowerBound < right.lines.lowerBound
      }
      return left.side == .committed && right.side == .onDisk
    }
  }
}
