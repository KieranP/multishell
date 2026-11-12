import MultishellAppCore
import MultishellCore

/// What a file tab's view last placed its cards from, so an update places
/// them again only when one of these moved.
struct ShownReviewCards: Equatable {
  let placements: [ReviewCardPlacement]
  let theme: Theme
  let metrics: UIMetrics

  /// The tab's cards for `lines`, its Unified rows or the `side` column's.
  @MainActor
  init(
    of tab: FileTab,
    in lines: [DiffLine],
    model: AppModel,
    theme: Theme,
    side: DiffSide? = nil,
  ) {
    placements = model.reviewCardPlacements(of: tab, in: lines, side: side)
    self.theme = theme
    metrics = model.metrics
  }
}
