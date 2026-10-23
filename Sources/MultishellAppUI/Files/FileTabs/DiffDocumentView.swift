import AppKit
import MultishellAppCore
import MultishellCore

/// A file tab's text in its scroller with the gutter beside it, the gutter
/// following the clip's every scroll.
@MainActor
final class DiffDocumentView: NSView {
  let textView: DiffTextView
  private let gutter: DiffGutterView
  private let scrollView = NSScrollView()
  private var observers: [any NSObjectProtocol] = []
  /// The clip's new origin each time it scrolls, which a split's other side follows.
  var onScroll: ((NSPoint) -> Void)?
  /// The same by the file's line at the top, for the model to keep while a
  /// hidden tab drops the view.
  var onScrolledTo: ((FileTabScroll) -> Void)?
  /// Taken once the view has a size and text; until then no scroll is
  /// reported, or the restore would be overwritten with the top.
  private var pendingRestore: FileTabScroll?
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

  /// Whose line numbers the gutter shows.
  var numbering: DiffSide {
    get { gutter.numbering }
    set { gutter.numbering = newValue }
  }

  var scrollOrigin: NSPoint { scrollView.contentView.bounds.origin }
  var clipHeight: CGFloat { scrollView.contentView.bounds.height }
  /// The row at the top, a fraction where one is cut.
  var topRow: Double {
    textView.geometry.topRow(atScrollOffset: scrollOrigin.y)
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
    addSubview(gutter)
    addSubview(scrollView)
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
    pendingRestore = scroll
    needsLayout = true
  }

  func awaitTheLock() {
    isAwaitingTheLock = true
  }

  func show(_ text: DiffDisplayText, theme: Theme) {
    let offset = scrollView.contentView.bounds.origin
    let anchorBefore = textView.displayText.scroll(atRow: topRow, x: offset.x)
    let isRestoring = pendingRestore != nil
    gutter.displayText = text
    gutter.apply(theme)
    let steppedChangeAnchor = takeSteppedChangeAnchorToCarry(boxedIn: textView.displayText)
    textView.show(text, theme: theme)
    carrySteppedChange(steppedChangeAnchor, into: text)
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
    let gutterWidth = gutter.preferredWidth
    gutter.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
    scrollView.frame = NSRect(
      x: gutterWidth,
      y: 0,
      width: max(0, bounds.width - gutterWidth),
      height: bounds.height,
    )
    textView.setFrameSize(textView.frame.size)
    if let scroll = pendingRestore, scrollView.contentView.bounds.height > 0,
      !textView.displayText.lines.isEmpty
    {
      pendingRestore = nil
      let y = textView.geometry.scrollOffset(puttingAtTop: textView.displayText.row(of: scroll))
      let clip = scrollView.contentView
      let target = clip.constrainBoundsRect(
        NSRect(origin: NSPoint(x: scroll.x, y: y), size: clip.bounds.size)
      ).origin
      restoredOrigin = target
      self.scroll(to: target)
    }
    followScroll()
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

  private func followScroll() {
    let origin = scrollView.contentView.bounds.origin
    gutter.scrolledTo = origin.y
    textView.layOutRowsAroundView()
    if origin.x != lastScrollX {
      lastScrollX = origin.x
      textView.redraw(steppedChange: textView.steppedChange)
    }
    onStepOriginMoved?()
    guard pendingRestore == nil, !isAwaitingTheLock else { return }
    onScroll?(origin)
    guard restoredOrigin != origin else { return }
    restoredOrigin = nil
    onScrolledTo?(textView.displayText.scroll(atRow: topRow, x: origin.x))
  }

  isolated deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
