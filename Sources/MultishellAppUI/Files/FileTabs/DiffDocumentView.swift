import AppKit
import MultishellAppCore
import MultishellCore

/// A file tab's text in its scroller with the gutter beside it, the gutter
/// following the clip's every scroll.
@MainActor
final class DiffDocumentView: NSView {
  let textView: DiffTextView
  let gutter: DiffGutterView
  private let scrollView = WheelForwardingScrollView()
  private var observers: [any NSObjectProtocol] = []
  /// The clip's new origin each time it scrolls, which a split's other side follows.
  var onScroll: ((NSPoint) -> Void)?
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
  /// Set by a split around its columns' layout, whose card gaps open after it.
  var defersPendingScrolls = false
  /// A split side whose other side restores: its own scroll is the lock's to
  /// set, and reporting before that would save the top.
  private var isAwaitingTheLock = false
  /// Where a restore or the lock after one left the clip: reported back, the
  /// split's anchor would replace the one the model handed over.
  private var restoredOrigin: NSPoint?
  private var lastScrollX: CGFloat = 0
  /// Every scroll and selection move, after which `changeSteps` may differ.
  var onStepOriginMoved: (() -> Void)?
  /// The rows this side boxed or let go of, which a split's other side mirrors
  /// and whose owner turns into an anchor for the model to keep.
  var onSteppedRowsChanged: ((Range<Int>?) -> Void)?
  /// The box a dropped view of this tab had, taken once the text is shown.
  var pendingSteppedChangeAnchor: ChangeAnchor?
  let reviewCards = ReviewCardLayer()
  /// Views across the gutter and the text in the gaps, laid out as the clip
  /// scrolls: the All changes tab's headers, folds and notices.
  let spanningGapViews = SpanningGapViewsLayer()
  /// Room before the gutter, the All changes tab's margin beside each file's
  /// box; a file tab's runs edge to edge.
  var leadingInset: CGFloat = 0 {
    didSet { if leadingInset != oldValue { needsLayout = true } }
  }

  /// Where set, a wheel over this view turns that scroller instead: a file the
  /// All changes tab shows whole is scrolled by the split around it.
  var forwardsScrollWheel: NSView? {
    get { scrollView.forwardsWheelTo }
    set { scrollView.forwardsWheelTo = newValue }
  }
  /// Where the cards are laid out again, so views hosted in the same gaps are too:
  /// the All changes tab's headers, folds and notices.
  var onGapViewsLaidOut: ((DiffRowGeometry, CGFloat) -> Void)?
  /// The gap each card's row needs, as the cards or the clip's width change: a
  /// split opens both columns' alike so the lock holds, Unified its own.
  var onReviewCardGaps: (([Int: CGFloat]) -> Void)?
  /// Lines the gutter or Comment on Lines picked, for the model's composer.
  var onCommentOnLines: ((ReviewLineSelection) -> Void)?
  /// Where set, takes the rows picked in place of `onCommentOnLines`, from the
  /// row a drag started on: the All changes tab reads them as one file's lines.
  var onCommentOnRows: ((_ start: Int, _ end: Int, _ side: DiffSide?) -> Void)?

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
    didSet { if minimumGutterWidth != oldValue { needsLayout = true } }
  }

  /// Whose line numbers the gutter shows.
  var numbering: DiffSide {
    get { gutter.numbering }
    set { gutter.numbering = newValue }
  }

  var scrollOrigin: NSPoint { scrollView.contentView.bounds.origin }
  /// Room right of the clip for the vertical scroller, the All changes tab
  /// putting it in the margin beside the file boxes.
  var scrollerMargin: CGFloat {
    get { scrollView.trailingContentInset }
    set { scrollView.trailingContentInset = newValue }
  }

  /// A split's left column in the All changes tab has none: the right's
  /// scroller moves both, the left's having scrolled it alone.
  var showsVerticalScroller: Bool {
    get { scrollView.hasVerticalScroller }
    set { scrollView.hasVerticalScroller = newValue }
  }

  var clipHeight: CGFloat { scrollView.contentView.bounds.height }
  var clipWidth: CGFloat { scrollView.contentView.bounds.width }
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
    super.init(frame: .zero)
    // Views no longer clip by default, and TextKit 2 draws past what the clip
    // shows: unclipped, the text's background covered the header and the strip.
    clipsToBounds = true
    scrollView.contentView.clipsToBounds = true
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.documentView = textView
    scrollView.contentView.postsBoundsChangedNotifications = true
    addSubview(scrollView)
    // Over the clip and under the scrollers, so a header across the gutter
    // never covers the scroller.
    scrollView.addSubview(gutter, positioned: .above, relativeTo: scrollView.contentView)
    scrollView.addSubview(spanningGapViews, positioned: .above, relativeTo: gutter)
    spanningGapViews.scrollsWith = scrollView
    gutter.onCommentOnRows = { [weak self] start, end in self?.commentOnRows(from: start, to: end) }
    textView.onCommentOnRows = { [weak self] rows in
      self?.commentOnRows(from: rows.lowerBound, to: rows.upperBound)
    }
    let scrolled: @MainActor @Sendable (DiffDocumentView) -> Void = { $0.followScroll() }
    let selected: @MainActor @Sendable (DiffDocumentView) -> Void = { $0.selectionMoved() }
    observers =
      NotificationCenter.default.observe(
        [(NSView.boundsDidChangeNotification, scrolled)],
        for: self,
        from: scrollView.contentView,
      )
      + NotificationCenter.default.observe(
        [(NSTextView.didChangeSelectionNotification, selected)],
        for: self,
        from: textView,
      )
  }

  required init?(coder: NSCoder) { nil }

  /// Where a dropped view of this tab was left.
  func restore(_ scroll: FileTabScroll) {
    pendingRestore = .line(scroll)
    needsLayout = true
  }

  func restore(toRow row: Double, x: Double) {
    pendingRestore = .row(row, x: x)
    needsLayout = true
  }

  /// A reveal asked for is where the user wants to be, not where the tab was left,
  /// so a restore waiting here, or this column's wait for the other's, is dropped.
  func cancelPendingRestore() {
    pendingRestore = nil
    isAwaitingTheLock = false
  }

  func awaitTheLock() {
    isAwaitingTheLock = true
  }

  /// `anchoring` carries the boxed change where the text alone cannot, the
  /// All changes tab's rows being several files'.
  func show(
    _ text: DiffDisplayText,
    theme: Theme,
    anchoredBy anchoring: (any ChangeAnchoring)? = nil,
  ) {
    let offset = scrollView.contentView.bounds.origin
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
    needsLayout = true
    layoutSubtreeIfNeeded()
    // A re-read keeps the scroll where it was, within what is left, unless a
    // restore was waiting: its layout may just have taken it.
    guard !isRestoring else {
      followScroll()
      return
    }
    // New text with a new line at the top under the same clip offset is a
    // place to report; the same line there keeps the anchor handed over.
    if text.scroll(atRow: topRow, x: offset.x) != anchorBefore { restoredOrigin = nil }
    scrollView.contentView.scroll(
      to: scrollView.contentView.constrainBoundsRect(
        NSRect(origin: offset, size: scrollView.contentView.bounds.size)
      ).origin
    )
    scrollView.reflectScrolledClipView(scrollView.contentView)
    followScroll()
  }

  override func layout() {
    super.layout()
    let gutterWidth = max(gutter.preferredWidth, minimumGutterWidth)
    scrollView.frame = NSRect(
      x: leadingInset,
      y: 0,
      width: max(0, bounds.width - leadingInset),
      height: bounds.height,
    )
    scrollView.leadingContentInset = gutterWidth
    gutter.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
    spanningGapViews.frame = scrollView.bounds
    textView.setFrameSize(textView.frame.size)
    if let gaps = reviewCards.remeasure(atClipWidth: scrollView.contentView.bounds.width) {
      openReviewCardGaps(gaps)
    }
    layOutGapViews()
    if !defersPendingScrolls { applyPendingScrolls() }
    followScroll()
  }

  /// The saved scroll and a card Review asked for, once the view has a size. A
  /// split runs them itself, after both columns' card gaps are open.
  func applyPendingScrolls() {
    if let restore = pendingRestore, scrollView.contentView.bounds.height > 0,
      !textView.displayText.lines.isEmpty
    {
      pendingRestore = nil
      let (row, x) =
        switch restore {
        case .line(let scroll): (textView.displayText.row(of: scroll), scroll.x)
        case .row(let row, let x): (row, x)
        }
      let y = textView.geometry.scrollOffset(puttingAtTop: row)
      let clip = scrollView.contentView
      let target = clip.constrainBoundsRect(
        NSRect(origin: NSPoint(x: x, y: y), size: clip.bounds.size)
      ).origin
      restoredOrigin = target
      self.scroll(to: target)
    }
    if let card = pendingCardReveal, scrollView.contentView.bounds.height > 0 {
      pendingCardReveal = nil
      revealReviewCard(card)
    }
  }

  /// Clamped. A restore, a step and a split's lock, which passes the other side's
  /// origin exactly, the same rows under the forced geometry; the split guards the echo.
  func scroll(to origin: NSPoint) {
    defer {
      if isAwaitingTheLock { restoredOrigin = scrollView.contentView.bounds.origin }
      isAwaitingTheLock = false
    }
    let clip = scrollView.contentView
    guard clip.bounds.origin != origin else { return }
    clip.scroll(
      to: clip.constrainBoundsRect(NSRect(origin: origin, size: clip.bounds.size)).origin
    )
    scrollView.reflectScrolledClipView(clip)
  }

  /// The cards and whatever else sits in the gaps, at the clip's sideways offset.
  func layOutGapViews() {
    reviewCards.layOut(in: textView.geometry, scrolledTo: scrollOrigin.x)
    onGapViewsLaidOut?(textView.geometry, scrollOrigin.x)
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

  private func followScroll() {
    let origin = scrollView.contentView.bounds.origin
    gutter.scrolledTo = origin.y
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
    guard pendingRestore == nil, !isAwaitingTheLock else { return }
    onScroll?(origin)
    guard restoredOrigin != origin else { return }
    restoredOrigin = nil
    onScrolledTo?(textView.displayText.scroll(atRow: topRow, x: origin.x))
    onTopRowMoved?(topRow, origin.x)
  }

  isolated deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
