import MultishellCore

extension ResizablePanel {
  /// Rounded up so a fraction truncates no row, within what a drag reaches.
  public static func fitted(toRowsOf rowsWidth: Double, in range: ClosedRange<Double>) -> Double {
    rowsWidth.rounded(.up).clamped(to: range)
  }
}
