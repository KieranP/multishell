/// Room split evenly between items held to a floor and, where given, a cap:
/// what a tab strip and the board both lay out by.
struct EvenShare {
  let width: Double
  /// Whether the items at that width overrun the room, so it scrolls rather
  /// than squeezing them further.
  let scrolls: Bool

  init(available: Double, count: Int, minimum: Double, maximum: Double? = nil) {
    let floor = max(minimum, 1)
    let ceiling = maximum.map { max($0, floor) }
    // Nothing to draw, or room not laid out yet: the cap, else the floor, and
    // no scrolling, which is the kindest first frame.
    guard count > 0, available.isFinite else {
      self.width = ceiling ?? floor
      self.scrolls = false
      return
    }
    // No room at all: reading this as "no scrolling" spills a full-width item
    // over whatever is beside it.
    guard available > 0 else {
      self.width = floor
      self.scrolls = true
      return
    }
    let share = available / Double(count)
    self.width = min(max(share, floor), ceiling ?? .infinity)
    // Asked of the share rather than of the total, which for room that
    // divides exactly is a floating-point coin toss.
    self.scrolls = share < floor
  }
}
