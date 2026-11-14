import AppKit
import MultishellAppCore
import MultishellCore

/// The committed side on the left, the file on disk on the right, two columns
/// on one canvas under one scroller, the same row on both sides under forced
/// geometry; see files/file-tabs.md.
@MainActor
final class SplitDiffDocumentView: DiffCanvasView {
  let committed: DiffColumn
  let onDisk: DiffColumn
  let divider = NSView()

  private var split: SplitDiff?
  /// What carries the box: the split, or the All changes tab's document.
  private var anchoring: (any ChangeAnchoring)?
  /// Gaps beyond the cards', opened in both columns: the All changes tab's
  /// headers, folds and notices, which `spanningGapViews` holds.
  var extraRowGaps: [Int: CGFloat] = [:] {
    didSet { if extraRowGaps != oldValue { openMergedReviewCardGaps() } }
  }
  /// Where the divider runs in the document: the All changes tab's files, not
  /// above the first header or under the last box; `nil` for the whole height.
  var dividerSpan: ClosedRange<CGFloat>? {
    didSet { if dividerSpan != oldValue { placeColumns() } }
  }
  /// Where the spanning views are laid out again: the geometry and the cards'
  /// gap under each row.
  var onSpanningGapViewsLaidOut: ((DiffRowGeometry, [Int: CGFloat]) -> Void)?
  /// By the right side's scroll, anchored by the split as a whole: the
  /// committed line where the left shows a removal.
  var onScrolledTo: ((FileTabScroll) -> Void)?
  /// From the side holding the keyboard, as a step counts.
  var onStepsCounted: ((ChangeSteps) -> Void)?
  /// The change either side boxed or let go of, as Unified holds it, for the
  /// model to keep.
  var onSteppedChangeAnchorChanged: ((ChangeAnchor?) -> Void)?
  private var firstResponderWatch: NSKeyValueObservation?
  /// Each column's card gaps, opened in both at each row's taller.
  private var columnGaps: [ObjectIdentifier: [Int: CGFloat]] = [:]
  private var isGatheringReviewCardGaps = false

  /// The right where neither side has the keyboard, as find counts there.
  private var keyboardSide: DiffColumn {
    committed.textView.isFirstResponder ? committed : onDisk
  }

  private var mergedCardGaps: [Int: CGFloat] {
    columnGaps.values.reduce(into: [Int: CGFloat]()) { merged, column in
      merged.merge(column, uniquingKeysWith: max)
    }
  }

  init(geometry: DiffRowGeometry) {
    committed = DiffColumn(geometry: geometry)
    onDisk = DiffColumn(geometry: geometry)
    super.init(columns: [committed, onDisk])
    committed.numbering = .committed
    committed.commentSide = .committed
    onDisk.commentSide = .onDisk
    committed.textView.copiesAsDiff = false
    onDisk.textView.copiesAsDiff = false
    divider.wantsLayer = true
    canvas.addSubview(divider, positioned: .below, relativeTo: spanningGapViews)
    onDisk.onScrolledTo = { [weak self] onDiskScroll in
      guard let self else { return }
      onScrolledTo?(split?.scroll(atRow: onDisk.topRow, x: onDiskScroll.x) ?? onDiskScroll)
    }
    for side in [committed, onDisk] {
      side.onReviewCardGaps = { [weak self, weak side] gaps in
        guard let self, let side else { return }
        openReviewCardGaps(gaps, of: side)
      }
    }
    for (side, other) in [(committed, onDisk), (onDisk, committed)] {
      side.onSteppedRowsChanged = { [weak self, weak other] rows in
        other?.mirrorSteppedChange(rows)
        self?.onSteppedChangeAnchorChanged?(
          rows.flatMap { self?.anchoring?.anchor(ofChangeAt: $0) }
        )
      }
      side.onStepOriginMoved = { [weak self, weak side] in
        guard let self, let side, side === keyboardSide else { return }
        countKeyboardSide()
      }
    }
    onScroll = { [weak self] in self?.layOutSpanningGapViews() }
  }

  required init?(coder: NSCoder) { nil }

  /// The All changes tab's, by its document's row.
  func restore(toRow row: Double, x: Double) {
    onDisk.restore(toRow: row, x: x)
  }

  /// On the side that has the line; the other moves with it.
  func restore(_ scroll: FileTabScroll) {
    (scroll.isCommittedLine ? committed : onDisk).restore(scroll)
  }

  /// Both sides' changes sit on the same rows, so either side's step is the
  /// split's, and the box's mirror brings the other along.
  func step(toChange direction: CycleDirection) {
    keyboardSide.step(toChange: direction)
  }

  /// Where a dropped view of this tab, Unified or Split, boxed a change; the
  /// right side's to take, as it holds a box the split carries.
  func restoreSteppedChangeAnchor(_ anchor: ChangeAnchor) {
    onDisk.restoreSteppedChangeAnchor(anchor)
  }

  /// The keyboard can cross sides with no scroll or selection to count on;
  /// a move between other views of the window is not counted.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    firstResponderWatch = window?.observe(\.firstResponder, options: [.old, .new]) {
      [weak self] _, change in
      let movedBetween = [change.oldValue, change.newValue].compactMap { $0 ?? nil }
        .map(ObjectIdentifier.init)
      MainActor.assumeIsolated {
        guard let self else { return }
        let sides = [self.committed.textView, self.onDisk.textView].map(ObjectIdentifier.init)
        if movedBetween.contains(where: sides.contains) { self.countKeyboardSide() }
      }
    }
  }

  /// The column holding the comment's card scrolls, and the other with it;
  /// neither column's saved scroll may then undo it.
  func revealReviewCard(_ card: ReviewCardPlacement.CardID) {
    let holding = [committed, onDisk].first { $0.reviewCards.rows(of: card) != nil }
    guard let column = holding else { return }
    committed.cancelPendingRestore()
    onDisk.cancelPendingRestore()
    column.revealReviewCard(card)
  }

  /// A column without a card at a row shows an empty gap as tall as the
  /// other's, so the same offset stays the same row on both sides.
  private func openReviewCardGaps(_ gaps: [Int: CGFloat], of side: DiffColumn) {
    columnGaps[ObjectIdentifier(side)] = gaps
    guard !isGatheringReviewCardGaps else { return }
    openMergedReviewCardGaps()
  }

  /// Both columns' cards placed before their merged gaps open, once: each
  /// opening lays the whole text out again.
  func placeReviewCards(_ place: () -> Void) {
    isGatheringReviewCardGaps = true
    place()
    isGatheringReviewCardGaps = false
    openMergedReviewCardGaps()
  }

  private func openMergedReviewCardGaps() {
    let rowGaps = RowGaps(mergedCardGaps.merging(extraRowGaps, uniquingKeysWith: +))
    defer { layOutSpanningGapViews() }
    guard
      committed.textView.geometry.rowGaps != rowGaps || onDisk.textView.geometry.rowGaps != rowGaps
    else { return }
    let anchor = onDisk.scrollAnchor
    committed.setRowGaps(rowGaps)
    onDisk.setRowGaps(rowGaps)
    onDisk.scroll(toAnchor: anchor)
  }

  private func countKeyboardSide() {
    onStepsCounted?(keyboardSide.changeSteps)
  }

  /// The box is carried by the split as a whole, once both sides are shown, on
  /// the side holding the keyboard, whose mirror then has its new rows to box.
  /// `anchoring` carries the box where the split alone cannot, the All changes
  /// tab's rows being several files'.
  func show(_ split: SplitDiff, theme: Theme, anchoredBy anchoring: (any ChangeAnchoring)? = nil) {
    let steppedChangeAnchor = onDisk.takeSteppedChangeAnchorToCarry(boxedIn: self.anchoring)
    // Unboxed first, so neither side carries the box by its own half of the change.
    committed.mirrorSteppedChange(nil)
    onDisk.mirrorSteppedChange(nil)
    self.split = split
    self.anchoring = anchoring ?? split
    divider.layer?.backgroundColor = theme.splitDividerColor.cgColor
    committed.show(split.committed, theme: theme)
    onDisk.show(split.onDisk, theme: theme)
    keyboardSide.carrySteppedChange(steppedChangeAnchor, into: anchoring ?? split)
    // Each side counted as it was shown, before the box was carried.
    countKeyboardSide()
  }

  override func columnSpans(inWidth width: CGFloat) -> [(x: CGFloat, width: CGFloat)] {
    let half = ((width - 1) / 2).rounded(.down)
    return [(0, half), (half + 1, max(0, width - half - 1))]
  }

  override func didPlaceColumns(
    _ spans: [(x: CGFloat, width: CGFloat)],
    x: CGFloat,
    height: CGFloat,
  ) {
    guard let right = spans.last else { return }
    let span = dividerSpan ?? 0...height
    divider.frame = NSRect(
      x: x + right.x - 1,
      y: span.lowerBound,
      width: 1,
      height: max(0, span.upperBound - span.lowerBound),
    )
  }

  /// Both columns' cards measured before the merged gaps open once, then each
  /// column's saved scroll or reveal on them.
  override func layOutColumns() {
    let columns = [committed, onDisk]
    for column in columns { column.defersPendingScrolls = true }
    placeReviewCards {
      for column in columns { column.layOut() }
    }
    // A restore or a reveal worked out before the gaps open would miss them.
    for column in columns {
      column.defersPendingScrolls = false
      column.applyPendingScrolls()
    }
    layOutSpanningGapViews()
  }

  /// Under the columns' gaps and the cards in them.
  private func layOutSpanningGapViews() {
    onSpanningGapViewsLaidOut?(onDisk.textView.geometry, mergedCardGaps)
  }
}
