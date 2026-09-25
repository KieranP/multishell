extension SplitMath {
  /// The length `count` panes share once the dividers between them take theirs.
  public static func available(_ length: Double, panes count: Int, divider: Double) -> Double {
    max(length - Double(count - 1) * divider, 0)
  }

  /// Each pane's length, `available` shared by weight, or evenly where the
  /// weights sum to nothing.
  public static func sizes(of weights: [Double], sharing available: Double) -> [Double] {
    let total = weights.reduce(0, +)
    return weights.map {
      total > 0 ? available * ($0 / total) : available / Double(weights.count)
    }
  }
}
