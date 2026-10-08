extension TabStripLayout {
  /// Which ends of a scrolled strip have tabs past them: one that scrolls
  /// without showing it has tabs nobody knows are there.
  public struct Overflow: Equatable, Sendable {
    public let hasTabsPastLeading: Bool
    public let hasTabsPastTrailing: Bool

    /// Half a point, so a strip scrolled to either end reads as having
    /// nothing further rather than fading against a rounding error.
    static let tolerance = 0.5

    /// `offset` is how far the strip is scrolled, `viewport` the room the
    /// tabs are seen through, `content` what they add up to.
    public init(offset: Double, viewport: Double, content: Double) {
      guard offset.isFinite, viewport.isFinite, content.isFinite else {
        self.hasTabsPastLeading = false
        self.hasTabsPastTrailing = false
        return
      }
      let travelled = max(offset, 0)
      let furthest = max(content - viewport, 0)
      self.hasTabsPastLeading = travelled > Self.tolerance
      self.hasTabsPastTrailing = travelled < furthest - Self.tolerance
    }
  }
}
