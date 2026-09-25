/// How wide a tab strip draws its tabs, and when it scrolls instead: they
/// shrink between a cap and a floor. See Docs/design/tabs-and-groups.md.
public struct TabStripLayout: Equatable, Sendable {
  /// What every tab is drawn, exactly. Uniform, so a drop can tell which
  /// half of a tab the pointer is in from this alone.
  public let tabWidth: Double
  /// Whether the tabs at that width overrun the strip, so it scrolls and
  /// clips rather than squeezing them further.
  public let scrolls: Bool

  /// `available` is the room the tabs have, the buttons at the end of the
  /// strip already taken off.
  public init(available: Double, count: Int, minimum: Double, maximum: Double) {
    let share = EvenShare(available: available, count: count, minimum: minimum, maximum: maximum)
    self.tabWidth = share.width
    self.scrolls = share.scrolls
  }
}
