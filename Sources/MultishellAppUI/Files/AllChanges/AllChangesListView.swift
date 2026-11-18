import AppKit
import MultishellAppCore
import MultishellCore

/// The files in one vertical scroller, a view each for those near the clip only;
/// see Docs/design/files/all-changes-tab.md.
@MainActor
final class AllChangesListView: NSView {
  private static var fileGap: CGFloat { CGFloat(UIMetrics.allChangesFileGap) }
  /// Views let go of and kept for the next files of their kind: building one
  /// anew for each file scrolled to cost some 150 MB while scrolling.
  private static let sparesKept = 6

  let scrollView = WheelForwardingScrollView()
  private let canvas = FlippedDocumentView()
  private var keys: [AllChangesFileKey] = []
  private var indexByKey: [AllChangesFileKey: Int] = [:]
  private var tops: [CGFloat] = []
  private var heights: [CGFloat] = []
  private var hosted: [AllChangesFileKey: AllChangesFileView] = [:]
  /// By whether they show Split's two columns.
  private var spares: [Bool: [AllChangesFileView]] = [:]
  private var observers: [any NSObjectProtocol] = []
  private var measured: [AllChangesFileKey: AllChangesMeasuredHeight] = [:]
  /// The file at `index`'s height before its view measures, a new view of
  /// Split's kind or not, and its content shown in a view.
  var estimate: ((Int) -> CGFloat)?
  var makeFile: ((_ isSplit: Bool) -> AllChangesFileView?)?
  var configure: ((AllChangesFileView, Int) -> Void)?
  /// The one Changes rotor across the files, which offer none of their own.
  var changesRotor: AllChangesChangesRotor?
  /// Each scroll, after the files near the clip are built.
  var onScroll: (() -> Void)?
  /// Each layout, once the files are placed: the first with a size can restore.
  var onLaidOut: (() -> Void)?
  /// The files built, as they change: those within half a clip of the clip.
  var onNearFiles: ((Range<Int>) -> Void)?
  private var reportedNear: Range<Int>?

  var leadingInset: CGFloat = 0 {
    didSet { if leadingInset != oldValue { needsLayout = true } }
  }

  var scrollerMargin: CGFloat {
    get { scrollView.trailingContentInset }
    set { scrollView.trailingContentInset = newValue }
  }

  var scrollY: CGFloat { scrollView.contentView.bounds.origin.y }
  var clipHeight: CGFloat { scrollView.contentView.bounds.height }
  private var isPlacementQueued = false
  /// A page down or up: the clip less the lines a scroller keeps in view and
  /// the sticky header covering the top.
  private var pageHeight: CGFloat {
    max(0, clipHeight - AllChangesFileView.headerHeight - scrollView.verticalPageScroll)
  }
  /// The few files built near the clip, in no order, with their places in the list.
  var builtFiles: [(index: Int, view: AllChangesFileView)] {
    hosted.compactMap { key, view in indexByKey[key].map { ($0, view) } }
  }
  override var acceptsFirstResponder: Bool { true }

  override init(frame: NSRect) {
    super.init(frame: frame)
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.horizontalScrollElasticity = .none
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.documentView = canvas
    scrollView.contentView.postsBoundsChangedNotifications = true
    addSubview(scrollView)
    let scrolled: @MainActor @Sendable (AllChangesListView) -> Void = { list in
      for view in list.hosted.values { view.forgetGutterHover() }
      list.buildNearClip()
      list.onScroll?()
    }
    observers = NotificationCenter.default.observe(
      [(NSView.boundsDidChangeNotification, scrolled)],
      for: self,
      from: scrollView.contentView,
    )
  }

  required init?(coder: NSCoder) { nil }

  /// New files, the file at the top held where it was.
  func show(_ keys: [AllChangesFileKey]) {
    let anchor = fileAnchor()
    self.keys = keys
    indexByKey = Dictionary(keepingFirst: keys.enumerated().map { ($1, $0) })
    // Other files may sit at the same indices, which the screen reports by.
    reportedNear = nil
    for (key, view) in hosted where indexByKey[key] == nil {
      retire(view)
      hosted[key] = nil
    }
    measured = measured.filter { indexByKey[$0.key] != nil }
    for (index, key) in keys.enumerated() {
      if let view = hosted[key] { configure?(view, index) }
    }
    place(holding: anchor)
  }

  /// The file at `index`'s top in the list, its box's top.
  func top(ofFile index: Int) -> CGFloat? {
    tops.indices.contains(index) ? tops[index] : nil
  }

  /// The file whose box, or the gap below it, holds `y`; the first file above its own gap.
  func fileIndex(at y: CGFloat) -> Int? {
    guard !tops.isEmpty else { return nil }
    return max(0, tops.partitioningIndex { $0 > y } - 1)
  }

  func file(at index: Int) -> AllChangesFileView? {
    keys.indices.contains(index) ? hosted[keys[index]] : nil
  }

  /// Where a scroll to `y` lands, held within the list's ends.
  func scrollY(reaching y: CGFloat) -> CGFloat {
    scrollView.clamped(NSPoint(x: 0, y: y)).y
  }

  func scroll(toY y: CGFloat) { scrollView.scrollClamped(to: NSPoint(x: 0, y: y)) }

  override func layout() {
    super.layout()
    let frame = NSRect(
      x: leadingInset,
      y: 0,
      width: max(0, bounds.width - leadingInset),
      height: bounds.height,
    )
    if scrollView.frame != frame { scrollView.frame = frame }
    place(holding: fileAnchor())
    onLaidOut?()
  }

  /// The file at the clip's top, by path so a switch to Split keeps it, and
  /// how far into it the top sits.
  private func fileAnchor() -> (path: String, offset: CGFloat)? {
    guard let index = fileIndex(at: scrollY) else { return nil }
    return (keys[index].path, scrollY - tops[index])
  }

  private func place(holding anchor: (path: String, offset: CGFloat)?) {
    var top = Self.fileGap
    tops = []
    heights = []
    for (index, key) in keys.enumerated() {
      let height = hosted[key]?.height ?? measuredOrEstimatedHeight(of: key, at: index)
      tops.append(top)
      heights.append(height)
      top += height + Self.fileGap
    }
    let width = scrollView.contentView.bounds.width
    let size = NSSize(width: width, height: max(top, clipHeight))
    if canvas.frame.size != size { canvas.setFrameSize(size) }
    if let anchor, let index = keys.firstIndex(where: { $0.path == anchor.path }) {
      scroll(toY: tops[index] + anchor.offset)
    }
    buildNearClip()
  }

  private func measuredOrEstimatedHeight(of key: AllChangesFileKey, at index: Int) -> CGFloat {
    let estimated = estimate?(index) ?? 0
    guard let last = measured[key], last.estimate == estimated else { return estimated }
    return last.height
  }

  /// Builds the files within half a clip of the clip and lets go of the rest.
  private func buildNearClip() {
    // Half a clip either side: enough for a short scroll, few views at once.
    guard let first = fileIndex(at: scrollY - clipHeight / 2) else { return }
    let end = scrollY + clipHeight * 1.5
    var near: Set<AllChangesFileKey> = []
    var index = first
    while index < keys.count, tops[index] <= end {
      let key = keys[index]
      near.insert(key)
      // None where the representable that makes files is gone mid-update.
      guard let view = hosted[key] ?? build(key, at: index) else {
        index += 1
        continue
      }
      let frame = NSRect(
        x: 0,
        y: tops[index],
        width: scrollView.contentView.bounds.width,
        height: heights[index],
      )
      if view.frame != frame { view.frame = frame }
      index += 1
    }
    if reportedNear != first..<index {
      reportedNear = first..<index
      onNearFiles?(first..<index)
    }
    for (key, view) in hosted where !near.contains(key) {
      if let index = indexByKey[key] {
        measured[key] = AllChangesMeasuredHeight(
          height: view.height,
          estimate: estimate?(index) ?? 0,
        )
      }
      retire(view)
      hosted[key] = nil
    }
  }

  private func retire(_ view: AllChangesFileView) {
    // Cleared while still focused, so the tab's selection for find is cleared too.
    view.forgetShownFile()
    // A hidden view's text keeps no keys: Cmd+Up then beeped (owner's report).
    if let focused = window?.firstResponder as? NSView, focused.isDescendant(of: view) {
      window?.makeFirstResponder(self)
    }
    let isSplit = view.split != nil
    guard spares[isSplit, default: []].count < Self.sparesKept else {
      view.removeFromSuperview()
      return
    }
    view.isHidden = true
    spares[isSplit, default: []].append(view)
  }

  private func build(_ key: AllChangesFileKey, at index: Int) -> AllChangesFileView? {
    let view: AllChangesFileView
    if let spare = spares[key.isSplit]?.popLast() {
      spare.isHidden = false
      view = spare
    } else {
      guard let made = makeFile?(key.isSplit) else { return nil }
      view = made
      canvas.addSubview(view)
    }
    hosted[key] = view
    view.onHeightChanged = { [weak self, weak view] in
      guard let self, let view, view.superview != nil else { return }
      placeNextTurn()
    }
    configure?(view, index)
    return view
  }

  /// A turn later, as the height moves mid-layout of the file's own view; once
  /// for every file whose height moved meanwhile.
  private func placeNextTurn() {
    guard !isPlacementQueued else { return }
    isPlacementQueued = true
    Task { @MainActor [weak self] in
      guard let self else { return }
      isPlacementQueued = false
      place(holding: fileAnchor())
    }
  }

  override func accessibilityCustomRotors() -> [NSAccessibilityCustomRotor] {
    guard let changesRotor else { return [] }
    return [
      NSAccessibilityCustomRotor(label: t("rotor.changes"), itemSearchDelegate: changesRotor)
    ]
  }

  override func keyDown(with event: NSEvent) {
    interpretKeyEvents([event])
  }

  override func moveToBeginningOfDocument(_ sender: Any?) { scroll(toY: 0) }
  override func moveToEndOfDocument(_ sender: Any?) { scroll(toY: canvas.frame.height) }
  override func scrollToBeginningOfDocument(_ sender: Any?) { scroll(toY: 0) }
  override func scrollToEndOfDocument(_ sender: Any?) { scroll(toY: canvas.frame.height) }

  // Holding the keyboard on opening, or after a file view went, the list pages
  // and steps a line as a scroller does: unhandled, each key beeped.
  override func pageDown(_ sender: Any?) { scroll(by: pageHeight) }
  override func pageUp(_ sender: Any?) { scroll(by: -pageHeight) }
  override func scrollPageDown(_ sender: Any?) { scroll(by: pageHeight) }
  override func scrollPageUp(_ sender: Any?) { scroll(by: -pageHeight) }
  override func moveDown(_ sender: Any?) { scroll(by: scrollView.verticalLineScroll) }
  override func moveUp(_ sender: Any?) { scroll(by: -scrollView.verticalLineScroll) }
  override func scrollLineDown(_ sender: Any?) { scroll(by: scrollView.verticalLineScroll) }
  override func scrollLineUp(_ sender: Any?) { scroll(by: -scrollView.verticalLineScroll) }

  private func scroll(by delta: CGFloat) { scroll(toY: scrollY + delta) }

  isolated deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
