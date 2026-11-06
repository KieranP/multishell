import MultishellCore

extension ResizablePanel {
  /// Rounded up so a fraction truncates no row, within what a drag reaches.
  public static func fitted(_ idealWidth: Double, in range: ClosedRange<Double>) -> Double {
    idealWidth.rounded(.up).clamped(to: range)
  }
}
