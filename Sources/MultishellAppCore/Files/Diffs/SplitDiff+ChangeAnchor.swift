/// A split's change held as Unified holds it: each side shows half of it, the
/// removed lines on the left and the added on the right.
extension SplitDiff: ChangeAnchoring {
  public func anchor(ofChangeAt rows: Range<Int>) -> ChangeAnchor? {
    let left = committed.anchor(ofChangeAt: rows)
    guard left?.lineText == nil else { return left }
    return onDisk.anchor(ofChangeAt: rows) ?? left
  }

  /// As Unified decides, the left side holding every committed line; by text, the
  /// nearer of either side's, a moved line being removed on one and added on the other.
  public func change(at anchor: ChangeAnchor) -> Range<Int>? {
    guard committed.hasCommittedSideMoved(since: anchor) else {
      return committed.change(sharingCommittedLinesWith: anchor)
    }
    let nearest = [committed.nearestChange(holding: anchor), onDisk.nearestChange(holding: anchor)]
      .compactMap(\.self)
      .min { $0.distance < $1.distance }
    return nearest?.rows
  }
}
