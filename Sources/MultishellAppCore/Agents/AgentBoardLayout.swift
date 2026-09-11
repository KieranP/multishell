import Foundation

/// How wide the board draws its columns, and when it scrolls instead. A
/// floor but no cap, a card's message line using what width it is given.
public struct AgentBoardLayout: Equatable, Sendable {
  /// What every column is drawn, exactly.
  public let columnWidth: Double
  /// Whether the columns at that width overrun the board, so it scrolls
  /// rather than squeezing them further.
  public let scrolls: Bool

  /// `available` is the room the columns have, the gaps between them and the
  /// padding round them already taken off.
  public init(available: Double, count: Int, minimum: Double) {
    let floor = max(minimum, 1)
    // Nothing to draw, or a board that has not been laid out yet: the floor,
    // and no scrolling, which is the kindest first frame.
    guard count > 0, available.isFinite else {
      self.columnWidth = floor
      self.scrolls = false
      return
    }
    // A board with no room at all. Reading this as "no scrolling" spills a
    // full column over the sidebar.
    guard available > 0 else {
      self.columnWidth = floor
      self.scrolls = true
      return
    }
    let share = available / Double(count)
    self.columnWidth = max(share, floor)
    // Asked of the share rather than of the total, which for a board that
    // divides exactly is a floating-point coin toss.
    self.scrolls = share < floor
  }

  /// The room the columns have, gaps and padding taken off. Asked here so
  /// the view measures nothing.
  public static func available(
    width: Double, count: Int, gap: Double, padding: Double
  ) -> Double {
    guard count > 0, width.isFinite else { return 0 }
    return width - 2 * padding - Double(count - 1) * gap
  }
}
