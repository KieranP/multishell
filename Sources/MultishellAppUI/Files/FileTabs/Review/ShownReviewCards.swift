import MultishellAppCore
import MultishellCore

/// What a file or All changes tab's view last placed its cards from, so an
/// update places them again only when one of these moved.
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

  /// The cards of a file the All changes tab shows whole across Split's columns.
  @MainActor
  init(
    of tab: AllChangesTab,
    onWholeFile path: String,
    in lines: [DiffLine],
    model: AppModel,
    theme: Theme,
  ) {
    placements = model.reviewCardPlacements(of: tab, onWholeFile: path, in: lines)
    self.theme = theme
    metrics = model.metrics
  }

  /// One file's cards in the All changes list, on that file's own shown rows.
  @MainActor
  init(
    of tab: AllChangesTab,
    in document: AllChangesDocument,
    section: Int,
    model: AppModel,
    theme: Theme,
    side: DiffSide? = nil,
  ) {
    placements = model.reviewCardPlacements(of: tab, in: document, section: section, side: side)
    self.theme = theme
    metrics = model.metrics
  }
}
