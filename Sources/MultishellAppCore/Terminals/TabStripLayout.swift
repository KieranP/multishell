import Foundation
import MultishellCore

/// How wide a tab strip draws its tabs, and when it scrolls instead: they
/// shrink between a cap and a floor. See docs/design/tabs-and-columns.md.
public struct TabStripLayout: Equatable, Sendable {
  /// What every tab is drawn, exactly. Uniform, so a drop can tell which
  /// half of a tab the pointer is in from this alone.
  public let tabWidth: Double
  /// Whether the tabs at that width overrun the strip, so it scrolls and
  /// clips rather than squeezing them further.
  public let scrolls: Bool

  /// `available` is the room the tabs have, the New Tab button's own width
  /// already taken off.
  public init(available: Double, count: Int, minimum: Double, maximum: Double) {
    let floor = max(minimum, 1)
    let ceiling = max(maximum, floor)
    // Nothing to draw, or a strip that has not been laid out: the cap, and
    // no scrolling, which is the kindest first frame.
    guard count > 0, available.isFinite else {
      self.tabWidth = ceiling
      self.scrolls = false
      return
    }
    // A strip with no room at all: reading this as "no scrolling" spills a
    // full-width tab over the column beside it.
    guard available > 0 else {
      self.tabWidth = floor
      self.scrolls = true
      return
    }
    let share = available / Double(count)
    self.tabWidth = min(max(share, floor), ceiling)
    // Asked of the share rather than of the total, which for a strip that
    // divides exactly is a floating-point coin toss.
    self.scrolls = share < floor
  }
}

extension TabStripLayout {
  /// Which ends of a scrolled strip have tabs past them: one that scrolls
  /// without showing it has tabs nobody knows are there.
  public struct Edges: Equatable, Sendable {
    public let leading: Bool
    public let trailing: Bool

    /// Half a point, so a strip scrolled to either end reads as having
    /// nothing further rather than fading against a rounding error.
    static let tolerance = 0.5

    /// `offset` is how far the strip is scrolled, `viewport` the room the
    /// tabs are seen through, `content` what they add up to.
    public init(offset: Double, viewport: Double, content: Double) {
      guard offset.isFinite, viewport.isFinite, content.isFinite else {
        self.leading = false
        self.trailing = false
        return
      }
      let travelled = max(offset, 0)
      let furthest = max(content - viewport, 0)
      self.leading = travelled > Self.tolerance
      self.trailing = travelled < furthest - Self.tolerance
    }
  }
}

extension TabStripLayout {
  /// Which tab an end arrow brings into view: the first past that end, `nil`
  /// where there is none. A tab counts as seen if any of it is.
  public func stepTarget(
    towards placement: TerminalTab.Placement, offset: Double, viewport: Double, count: Int
  ) -> Int? {
    guard count > 0, tabWidth > 0, offset.isFinite, viewport.isFinite else { return nil }
    let travelled = max(offset, 0)
    let first = Int((travelled / tabWidth).rounded(.down))
    let last = Int(((travelled + max(viewport, 0)) / tabWidth).rounded(.up)) - 1

    switch placement {
    case .before:
      let target = min(first, count - 1) - 1
      return target >= 0 ? target : nil
    case .after:
      let target = max(last, 0) + 1
      return target <= count - 1 ? target : nil
    }
  }
}
