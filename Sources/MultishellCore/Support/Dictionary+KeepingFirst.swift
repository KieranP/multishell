extension Dictionary {
  /// Each pair's value by its key, the first kept where two share one.
  public init<Pairs: Sequence>(keepingFirst pairs: Pairs) where Pairs.Element == (Key, Value) {
    self.init(pairs, uniquingKeysWith: { first, _ in first })
  }
}
