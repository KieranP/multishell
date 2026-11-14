import AppKit
import MultishellAppCore
import MultishellCore

/// One side's gutter and text on a `DiffCanvasView`'s canvas, scrolled by the
/// canvas's one scroller: Unified's only column, or either side of Split.
@MainActor
final class DiffColumn {
  let textView: DiffTextView
  let gutter: DiffGutterView
  /// The text's own clip, so a sideways scroll moves the text and not the gutter.
  let textClip = NSView()
  weak var canvasView: DiffCanvasView?
  /// The same by the file's line at the top, for the model to keep while a
  /// hidden tab drops the view.
  var onScrolledTo: ((FileTabScroll) -> Void)?
  /// The same by the top row, a fraction where one is cut, and the sideways
  /// offset: the All changes tab holds its scroll by its document's file.
  var onTopRowMoved: ((Double, Double) -> Void)?
  /// Taken once the view has a size and text; until then no scroll is
  /// reported, or the restore would be overwritten with the top.
  private var pendingRestore: DiffScrollRestore?
  /// What the shown text's boxed change is carried by: the text itself, or the
  /// All changes tab's document, which knows each row's file.
  private var shownAnchoring: (any ChangeAnchoring)?
  /// A card Review asked to show before the view had a size; it wins over a restore.
  var pendingCardReveal: ReviewCardPlacement.CardID?
  /// A find's match asked to show before the view had a size; it wins too.
  private var pendingVisibleRect: NSRect?
  /// Set by a split around its columns' layout, whose card gaps open after it.
  var defersPendingScrolls = false
  private var lastScrollX: CGFloat = 0
  /// Every scroll and selection move, after which `changeSteps` may differ.
  var onStepOriginMoved: (() -> Void)?
  /// The rows this side boxed or let go of, which a split's other side mirrors
  /// and whose owner turns into an anchor for the model to keep.
  var onSteppedRowsChanged: ((Range<Int>?) -> Void)?
  /// The box a dropped view of this tab had, taken once the text is shown.
  var pendingSteppedChangeAnchor: ChangeAnchor?
  let reviewCards = ReviewCardLayer()
  /// Where the cards are laid out again, so views hosted in the same gaps are too:
  /// the All changes tab's headers, folds and notices.
  var onGapViewsLaidOut: ((DiffRowGeometry, CGFloat) -> Void)?
  /// The gap each card's row needs, as the cards or the clip's width change: a
  /// split opens both columns' alike, Unified its own.
  var onReviewCardGaps: (([Int: CGFloat]) -> Void)?
  /// Lines the gutter or Comment on Lines picked, for the model's composer.
  var onCommentOnLines: ((ReviewLineSelection) -> Void)?
  /// Where set, takes the rows picked in place of `onCommentOnLines`, from the
  /// row a drag started on: the All changes tab reads them as one file's lines.
  var onCommentOnRows: ((_ start: Int, _ end: Int, _ side: DiffSide?) -> Void)?
  private var selectionObserver: (any NSObjectProtocol)?

  /// A split column's side; `nil` in Unified, where each row's kind picks it.
  var commentSide: DiffSide? {
    get { gutter.commentSide }
    set {
      gutter.commentSide = newValue
      textView.commentSide = newValue
    }
  }

  /// A whole file in the All changes split lines its numbers up with the columns'.
  var minimumGutterWidth: CGFloat = 0 {
    didSet { if minimumGutterWidth != oldValue { canvasView?.needsLayout = true } }
  }

  var gutterWidth: CGFloat { max(gutter.preferredWidth, minimumGutterWidth) }

  /// Whose line numbers the gutter shows.
  var numbering: DiffSide {
    get { gutter.numbering }
    set { gutter.numbering = newValue }
  }

  /// The canvas's scroll: the clip's top in the document, and the sideways
  /// scroll both columns share.
  var scrollOrigin: NSPoint { canvasView?.scrollOrigin ?? .zero }
  var clipHeight: CGFloat { canvasView?.clipHeight ?? 0 }
  /// The text's own clip, right of the gutter.
  var clipWidth: CGFloat { textClip.frame.width }
  var hasPendingRestore: Bool { pendingRestore != nil }

  /// The row at the top, a fraction where one is cut.
  var topRow: Double {
    textView.geometry.topRow(atScrollOffset: scrollOrigin.y)
  }

  /// The row starting at or above the clip's top, so a point inside a card's gap counts.
  var scrollAnchor: ScrollAnchor {
    let top = scrollOrigin.y
    var row = Int(topRow)
    if row > 0, textView.geometry.top(ofRow: row) > top { row -= 1 }
    return ScrollAnchor(row: row, offsetBelowRow: top - textView.geometry.top(ofRow: row))
  }

  init(geometry: DiffRowGeometry) {
    textView = DiffTextView(geometry: geometry)
    gutter = DiffGutterView(geometry: geometry)
    // TextKit 2 draws past what the clip shows: unclipped, the text's
    // background covered the gutter and the views in the gaps.
    textClip.clipsToBounds = true
    textClip.addSubview(textView)
    gutter.onCommentOnRows = { [weak self] start, end in self?.commentOnRows(from: start, to: end) }
    textView.onCommentOnRows = { [weak self] rows in
      self?.commentOnRows(from: rows.lowerBound, to: rows.upperBound)
    }
    textView.scrollsRectToVisible = { [weak self] rect in
      self?.scrollTextRectToVisible(rect) ?? false
    }
    let selected: @MainActor @Sendable (DiffColumn) -> Void = { $0.selectionMoved() }
    selectionObserver =
      NotificationCenter.default.observe(
        [(NSTextView.didChangeSelectionNotification, selected)],
        for: self,
        from: textView,
      ).first
  }

  /// Where a dropped view of this tab was left.
  func restore(_ scroll: FileTabScroll) {
    pendingRestore = .line(scroll)
    canvasView?.needsLayout = true
  }

  func restore(toRow row: Double, x: Double) {
    pendingRestore = .row(row, x: x)
    canvasView?.needsLayout = true
  }

  /// A reveal asked for is where the user wants to be, not where the tab was
  /// left, so a restore waiting here is dropped.
  func cancelPendingRestore() {
    pendingRestore = nil
  }

  /// `anchoring` carries the boxed change where the text alone cannot, the
  /// All changes tab's rows being several files'.
  func show(
    _ text: DiffDisplayText,
    theme: Theme,
    anchoredBy anchoring: (any ChangeAnchoring)? = nil,
  ) {
    let offset = scrollOrigin
    let anchorBefore = textView.displayText.scroll(atRow: topRow, x: offset.x)
    let isRestoring = pendingRestore != nil
    gutter.displayText = text
    gutter.apply(theme)
    let steppedChangeAnchor = takeSteppedChangeAnchorToCarry(
      boxedIn: shownAnchoring ?? textView.displayText
    )
    textView.show(text, theme: theme)
    shownAnchoring = anchoring
    carrySteppedChange(steppedChangeAnchor, into: anchoring ?? text)
    canvasView?.needsLayout = true
    canvasView?.layoutSubtreeIfNeeded()
    // A re-read keeps the scroll where it was, within what is left, unless a
    // restore was waiting: its layout may just have taken it.
    guard !isRestoring else {
      followScroll()
      return
    }
    // New text with a new line at the top under the same clip offset is a
    // place to report; the same line there keeps the anchor handed over.
    if text.scroll(atRow: topRow, x: offset.x) != anchorBefore { canvasView?.restoredOrigin = nil }
    canvasView?.scroll(to: offset)
    followScroll()
  }

  /// The canvas's layout of this column: cards measured at the text's width,
  /// then the saved scroll, unless a split runs it after both columns' gaps open.
  func layOut() {
    if let gaps = reviewCards.remeasure(atClipWidth: clipWidth) {
      openReviewCardGaps(gaps)
    }
    layOutGapViews()
    if !defersPendingScrolls { applyPendingScrolls() }
    followScroll()
  }

  /// The saved scroll and a card Review asked for, once the view has a size. A
  /// split runs them itself, after both columns' card gaps are open.
  func applyPendingScrolls() {
    if let restore = pendingRestore, clipHeight > 0, !textView.displayText.lines.isEmpty {
      pendingRestore = nil
      let (row, x) =
        switch restore {
        case .line(let scroll): (textView.displayText.row(of: scroll), scroll.x)
        case .row(let row, let x): (row, x)
        }
      let y = textView.geometry.scrollOffset(puttingAtTop: row)
      let target = canvasView?.clamped(NSPoint(x: x, y: y)) ?? .zero
      canvasView?.restoredOrigin = target
      scroll(to: target)
    }
    if let rect = pendingVisibleRect, clipHeight > 0 {
      pendingVisibleRect = nil
      _ = scrollTextRectToVisible(rect)
    }
    if let card = pendingCardReveal, clipHeight > 0 {
      pendingCardReveal = nil
      revealReviewCard(card)
    }
  }

  /// Clamped by the canvas, which both columns of a split share.
  func scroll(to origin: NSPoint) {
    canvasView?.scroll(to: origin)
  }

  /// The cards and whatever else sits in the gaps, at the clip's sideways offset.
  func layOutGapViews() {
    reviewCards.layOut(in: textView.geometry, scrolledTo: scrollOrigin.x)
    onGapViewsLaidOut?(textView.geometry, scrollOrigin.x)
  }

  /// A find or the caret: the rect, in the text's coordinates, brought into the
  /// text's own clip, which the canvas's clip alone would not judge sideways.
  private func scrollTextRectToVisible(_ rect: NSRect) -> Bool {
    guard clipHeight > 0 else {
      pendingVisibleRect = rect
      cancelPendingRestore()
      canvasView?.needsLayout = true
      return false
    }
    let origin = scrollOrigin
    var target = origin
    if rect.minX < origin.x {
      target.x = rect.minX
    } else if rect.maxX > origin.x + clipWidth {
      target.x = min(rect.minX, rect.maxX - clipWidth)
    }
    if rect.minY < origin.y {
      target.y = rect.minY
    } else if rect.maxY > origin.y + clipHeight {
      target.y = min(rect.minY, rect.maxY - clipHeight)
    }
    guard target != origin else { return false }
    scroll(to: target)
    return true
  }

  private func commentOnRows(from start: Int, to end: Int) {
    if let onCommentOnRows {
      onCommentOnRows(start, end, commentSide)
      return
    }
    guard
      let selection = ReviewLineSelection(
        from: start,
        to: end,
        in: textView.displayText.lines,
        side: commentSide,
      )
    else { return }
    onCommentOnLines?(selection)
  }

  /// Run by the canvas on each scroll of its clip.
  func followScroll() {
    let origin = scrollOrigin
    gutter.hoveredRow = nil
    textView.layOutRowsAroundView()
    if origin.x != lastScrollX {
      lastScrollX = origin.x
      textView.redraw(steppedChange: textView.steppedChange)
      layOutGapViews()
    } else {
      // Gap views are hosted near the clip alone, so they follow every scroll.
      onGapViewsLaidOut?(textView.geometry, origin.x)
    }
    onStepOriginMoved?()
    guard let canvasView, !canvasView.isRestoring, canvasView.restoredOrigin != origin else {
      return
    }
    canvasView.restoredOrigin = nil
    onScrolledTo?(textView.displayText.scroll(atRow: topRow, x: origin.x))
    onTopRowMoved?(topRow, origin.x)
  }

  isolated deinit {
    if let selectionObserver { NotificationCenter.default.removeObserver(selectionObserver) }
  }
}
