/// A split's or a group's relative share. Zero, or one that is not a
/// number, is a pane nothing can be laid out in.
enum LayoutWeight {
  static func isUsable(_ weight: Double) -> Bool {
    weight.isFinite && weight > 0
  }

  /// A group's weight, an equal share standing in for an unusable one;
  /// `PaneNode` resets a split's whole list over one instead.
  static func usable(_ weight: Double) -> Double {
    isUsable(weight) ? weight : 1
  }

  static func allUsable(_ weights: [Double]) -> Bool {
    weights.allSatisfy(isUsable)
  }

  /// `weights` where there is one per child, else equal shares: indexed by
  /// child, a list that does not line up would drop panes or trap.
  static func aligned(_ weights: [Double], count: Int) -> [Double] {
    weights.count == count ? weights : Array(repeating: 1, count: count)
  }
}
