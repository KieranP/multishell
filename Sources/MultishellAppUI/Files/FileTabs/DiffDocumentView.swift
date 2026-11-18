import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// Unified: one column on the canvas, its gutter and text scrolled as one.
@MainActor
final class DiffDocumentView: DiffCanvasView {
  let column: DiffColumn

  var textView: DiffTextView { column.textView }
  var changeSteps: ChangeSteps { column.changeSteps }

  var onScrolledTo: ((FileTabScroll) -> Void)? {
    get { column.onScrolledTo }
    set { column.onScrolledTo = newValue }
  }
  var onStepOriginMoved: (() -> Void)? {
    get { column.onStepOriginMoved }
    set { column.onStepOriginMoved = newValue }
  }
  var onSteppedRowsChanged: ((Range<Int>?) -> Void)? {
    get { column.onSteppedRowsChanged }
    set { column.onSteppedRowsChanged = newValue }
  }
  var onGapViewsLaidOut: ((DiffRowGeometry, CGFloat) -> Void)? {
    get { column.onGapViewsLaidOut }
    set { column.onGapViewsLaidOut = newValue }
  }
  var onReviewCardGaps: (([Int: CGFloat]) -> Void)? {
    get { column.onReviewCardGaps }
    set { column.onReviewCardGaps = newValue }
  }
  var onCommentOnLines: ((ReviewLineSelection) -> Void)? {
    get { column.onCommentOnLines }
    set { column.onCommentOnLines = newValue }
  }

  init(geometry: DiffRowGeometry) {
    column = DiffColumn(geometry: geometry)
    super.init(columns: [column])
  }

  required init?(coder: NSCoder) { nil }

  func show(_ text: DiffDisplayText, theme: Theme) {
    column.show(text, theme: theme)
  }

  func restore(_ scroll: FileTabScroll) { column.restore(scroll) }
  func step(toChange direction: CycleDirection) { column.step(toChange: direction) }
  func restoreSteppedChangeAnchor(_ anchor: ChangeAnchor) {
    column.restoreSteppedChangeAnchor(anchor)
  }
  func revealReviewCard(_ card: ReviewCardPlacement.CardID) { column.revealReviewCard(card) }
  func setRowGaps(_ gaps: RowGaps) { column.setRowGaps(gaps) }
  func layOutGapViews() { column.layOutGapViews() }

  func showReviewCards(
    _ shown: ShownReviewCards,
    replacing last: inout ShownReviewCards?,
    model: AppModel,
    tabID: ReviewTabID,
  ) {
    column.showReviewCards(shown, replacing: &last, model: model, tabID: tabID)
  }
}
