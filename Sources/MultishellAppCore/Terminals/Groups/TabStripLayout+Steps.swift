import MultishellCore

extension TabStripLayout {
  /// One end of the strip, where an arrow is drawn.
  public enum End: Sendable {
    case leading
    case trailing
  }

  /// Which tab an end arrow brings into view: the one that end clips, else the
  /// one past it. In points, as `Overflow` draws the arrow in points.
  public func stepTarget(
    towards end: End, offset: Double, viewport: Double, count: Int
  ) -> Int? {
    guard count > 0, tabWidth > 0, offset.isFinite, viewport.isFinite else { return nil }
    let travelled = max(offset, 0)
    let target: Int
    switch end {
    case .leading:
      let boundary = (travelled / tabWidth).rounded(.down)
      let clips = travelled - boundary * tabWidth > Overflow.tolerance
      target = clampedIndex(boundary, count) - (clips ? 0 : 1)
    case .trailing:
      let edge = travelled + max(viewport, 0)
      let boundary = (edge / tabWidth).rounded(.up)
      let clips = boundary * tabWidth - edge > Overflow.tolerance
      target = clampedIndex(boundary, count) - (clips ? 1 : 0)
    }
    return (0..<count).contains(target) ? target : nil
  }

  /// A tab index off a measurement, held inside the strip before it becomes
  /// an `Int`: converting a huge one traps.
  private func clampedIndex(_ boundary: Double, _ count: Int) -> Int {
    Int(boundary.clamped(to: -1...Double(count) + 1))
  }
}
