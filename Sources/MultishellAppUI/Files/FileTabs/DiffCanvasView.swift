import AppKit
import MultishellAppCore

/// One scroller over a canvas holding each column's gutter and text and the
/// views in the gaps across them, so all of it scrolls as one document and
/// nothing is kept in step; see Docs/design/files/file-tabs.md. Unified has
/// one column, Split two.
@MainActor
class DiffCanvasView: NSView {
  let scrollView = WheelForwardingScrollView()
  let canvas = DiffCanvas()
  /// Views across the columns in the gaps: the All changes tab's headers,
  /// folds, notices and file boxes, placed by the document's offsets.
  let spanningGapViews = SpanningGapViewsLayer()
  private(set) var columns: [DiffColumn] = []
  /// Each scroll, after the columns followed it.
  var onScroll: (() -> Void)?
  /// Where a restore left the clip: reported back, a split's anchor would
  /// replace the one the model handed over.
  var restoredOrigin: NSPoint?
  /// A column waiting to restore: until it has, no column reports a scroll, or
  /// the restore would be overwritten with the top.
  var isRestoring: Bool { columns.contains(where: \.hasPendingRestore) }
  private var placedAtX: CGFloat = 0
  private var observers: [any NSObjectProtocol] = []

  /// Room before the columns, the All changes tab's margin beside each file's
  /// box; a file tab's runs edge to edge.
  var leadingInset: CGFloat = 0 {
    didSet { if leadingInset != oldValue { needsLayout = true } }
  }

  /// Room right of the clip for the vertical scroller, the All changes tab
  /// putting it in the margin beside the file boxes.
  var scrollerMargin: CGFloat {
    get { scrollView.trailingContentInset }
    set { scrollView.trailingContentInset = newValue }
  }

  /// Where set, a wheel over this view turns that scroller instead: a file the
  /// All changes tab shows whole is scrolled by the split around it.
  var forwardsScrollWheel: NSView? {
    get { scrollView.forwardsWheelTo }
    set { scrollView.forwardsWheelTo = newValue }
  }

  /// The clip's top in the document and the sideways scroll every column shares.
  var scrollOrigin: NSPoint { scrollView.contentView.bounds.origin }
  var clipHeight: CGFloat { scrollView.contentView.bounds.height }

  init(columns: [DiffColumn]) {
    self.columns = columns
    super.init(frame: .zero)
    clipsToBounds = true
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.documentView = canvas
    scrollView.contentView.postsBoundsChangedNotifications = true
    addSubview(scrollView)
    for column in columns {
      column.canvasView = self
      canvas.addSubview(column.gutter)
      canvas.addSubview(column.textClip)
    }
    canvas.addSubview(spanningGapViews)
    let scrolled: @MainActor @Sendable (DiffCanvasView) -> Void = { $0.clipScrolled() }
    observers = NotificationCenter.default.observe(
      [(NSView.boundsDidChangeNotification, scrolled)],
      for: self,
      from: scrollView.contentView,
    )
  }

  required init?(coder: NSCoder) { nil }

  /// Where `origin` lands once the clip's bounds hold it.
  func clamped(_ origin: NSPoint) -> NSPoint {
    let clip = scrollView.contentView
    return clip.constrainBoundsRect(NSRect(origin: origin, size: clip.bounds.size)).origin
  }

  /// Clamped; every column moves with it.
  func scroll(to origin: NSPoint) {
    let clip = scrollView.contentView
    let target = clamped(origin)
    guard clip.bounds.origin != target else { return }
    clip.scroll(to: target)
    scrollView.reflectScrolledClipView(clip)
  }

  /// Each column's span across the clip, left to right.
  func columnSpans(inWidth width: CGFloat) -> [(x: CGFloat, width: CGFloat)] {
    [(0, width)]
  }

  /// The canvas as tall as the tallest column and as wide as the clip plus the
  /// furthest any text runs past its own clip; the columns' gutters and clips
  /// held where the clip shows them, as a sideways scroll moves the text alone.
  func placeColumns() {
    let width = scrollView.contentView.bounds.width
    let x = scrollOrigin.x
    placedAtX = x
    let spans = columnSpans(inWidth: width)
    var overflow: CGFloat = 0
    var height = clipHeight
    for (column, span) in zip(columns, spans) {
      let text = column.textView
      overflow = max(overflow, text.documentWidth - (span.width - column.gutterWidth))
      height = max(height, text.geometry.documentHeight(rows: text.displayText.lines.count))
    }
    let canvasSize = NSSize(width: width + overflow, height: height)
    if canvas.frame.size != canvasSize { canvas.setFrameSize(canvasSize) }
    for (column, span) in zip(columns, spans) {
      let gutterWidth = column.gutterWidth
      let textWidth = max(0, span.width - gutterWidth)
      column.gutter.frame = NSRect(x: x + span.x, y: 0, width: gutterWidth, height: height)
      column.textClip.frame = NSRect(
        x: x + span.x + gutterWidth,
        y: 0,
        width: textWidth,
        height: height,
      )
      column.textView.setFrameOrigin(NSPoint(x: -x, y: 0))
      column.textView.setFrameSize(NSSize(width: textWidth + overflow, height: height))
    }
    spanningGapViews.frame = NSRect(x: x, y: 0, width: width, height: height)
    didPlaceColumns(spans, x: x, height: height)
  }

  /// For a split's divider, placed with the columns.
  func didPlaceColumns(_ spans: [(x: CGFloat, width: CGFloat)], x: CGFloat, height: CGFloat) {}

  /// Each column's cards and saved scroll, after the columns are placed.
  func layOutColumns() {
    for column in columns { column.layOut() }
  }

  override func layout() {
    super.layout()
    let frame = NSRect(
      x: leadingInset,
      y: 0,
      width: max(0, bounds.width - leadingInset),
      height: bounds.height,
    )
    if scrollView.frame != frame { scrollView.frame = frame }
    placeColumns()
    layOutColumns()
  }

  private func clipScrolled() {
    if scrollOrigin.x != placedAtX { placeColumns() }
    for column in columns { column.followScroll() }
    onScroll?()
  }

  isolated deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
