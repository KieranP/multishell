/// A matched row with what orders it among the others.
struct QuickSwitcherRankedRow {
  let score: Int
  let titleLength: Int
  let kindBias: Int
  let offset: Int
  let item: QuickSwitcherItem

  /// Best score first. A tie goes to the shorter title, a path's more general
  /// place, then the kind, then the order given.
  func precedes(_ other: Self) -> Bool {
    if score != other.score { return score > other.score }
    if titleLength != other.titleLength { return titleLength < other.titleLength }
    return kindBias != other.kindBias ? kindBias > other.kindBias : offset < other.offset
  }
}
