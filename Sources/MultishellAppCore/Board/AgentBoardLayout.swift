/// How wide the board draws its columns, and when it scrolls instead. A
/// floor but no cap, a card's message line using what width it is given.
public struct AgentBoardLayout: Equatable, Sendable {
  /// What every column is drawn, exactly.
  public let columnWidth: Double
  public let scrolls: Bool

  public init(available: Double, count: Int, minimum: Double) {
    let share = EvenShare(available: available, count: count, minimum: minimum)
    self.columnWidth = share.width
    self.scrolls = share.scrolls
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
