import AppKit
import MultishellAppCore

/// One scroller over each column's gutter and text and the gap views across them,
/// so nothing is kept in step; see Docs/design/files/file-tabs.md.
@MainActor
class DiffCanvasView: NSView {
  let scrollView = WheelForwardingScrollView()
  let canvas = FlippedDocumentView()
  /// Views across the columns in the gaps: the All changes tab's folds and
  /// notices, placed by the file's own rows.
  let spanningGapViews = SpanningGapViewsLayer()
  private let columns: [DiffColumn]
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

  /// Where set, a vertical wheel over this view turns that scroller instead:
  /// a file in the All changes list is scrolled by the list.
  var forwardsWheelTo: NSView? {
    get { scrollView.forwardsWheelTo }
    set { scrollView.forwardsWheelTo = newValue }
  }

  /// In the All changes list, which scrolls it to a caret, the height of the
  /// sticky header the caret stays below; `nil` in a tab of its own.
  var listHeaderHeight: CGFloat?

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
  func clamped(_ origin: NSPoint) -> NSPoint { scrollView.clamped(origin) }

  /// Clamped; every column moves with it.
  func scroll(to origin: NSPoint) { scrollView.scrollClamped(to: origin) }

  /// Each column's span across the clip, left to right.
  func columnSpans(inWidth width: CGFloat) -> [(x: CGFloat, width: CGFloat)] {
    [(0, width)]
  }

  /// The canvas as tall as the tallest column and wide enough for the longest text;
  /// gutters and clips held in view, as a sideways scroll moves the text alone.
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
    if scrollView.frame != bounds { scrollView.frame = bounds }
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
