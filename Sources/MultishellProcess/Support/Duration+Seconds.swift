extension Duration {
  /// As a `Double` of seconds, for an API that takes a time interval.
  public var inSeconds: Double {
    Double(components.seconds) + Double(components.attoseconds) / 1e18
  }
}
