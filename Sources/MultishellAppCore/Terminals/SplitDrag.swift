/// One divider drag over a split: the weights it began from, and the weights
/// it shows until it ends and hands them to the model.
public struct SplitDrag: Equatable, Sendable {
  private var startWeights: [Double]?
  /// Handed to the model once, at the end: each frame written through
  /// re-rendered every reader and re-armed autosave.
  private var shownWeights: [Double]?

  public init() {}

  public func shown(over weights: [Double]) -> [Double] { shownWeights ?? weights }

  /// Measured from where the drag began, so the weights it started from are
  /// kept until it ends.
  public mutating func move(
    dividerAfter index: Int, by translation: Double, over weights: [Double],
    available: Double, minimumPane: Double
  ) {
    let start = startWeights ?? weights
    if startWeights == nil { startWeights = start }
    let updated = SplitMath.transferring(
      translation, acrossDividerAfter: index, in: start, available: available,
      minimumPane: minimumPane)
    if updated != (shownWeights ?? start) { shownWeights = updated }
  }

  /// The model's weights changed under the drag, so they are what shows.
  public mutating func forgetShownWeights() { shownWeights = nil }

  /// The weights to hand the model, `nil` where the drag changed nothing.
  public mutating func end(over weights: [Double]) -> [Double]? {
    defer { self = SplitDrag() }
    guard let shownWeights, shownWeights != weights else { return nil }
    return shownWeights
  }
}
