import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// One file of the list: its header over its own Unified or Split diff in a box;
/// see Docs/design/files/all-changes-tab.md.
@MainActor
final class AllChangesFileView: NSView {
  static var headerHeight: CGFloat { CGFloat(UIMetrics.allChangesHeaderBarHeight) }

  /// Its diff: `unified`, or `split`'s two columns.
  let canvas: DiffCanvasView
  let unified: DiffDocumentView?
  let split: SplitDiffDocumentView?
  /// What find, highlighting and the arrows' box work on: Unified's column, or
  /// Split's right.
  let mainColumn: DiffColumn
  private let headerHost = NSHostingView(rootView: AnyView(EmptyView()))
  private var shownHeader: AllChangesFileHeader?
  private let gapLayer = AllChangesGapLayer()
  private(set) var slice: AllChangesFileSlice?
  private var theme: Theme?
  private var itemGaps: [Int: CGFloat] = [:]
  private var cardGaps: [Int: CGFloat] = [:]
  private var reportedHeight: CGFloat = 0
  var shownCards: ShownReviewCards?
  var shownCommittedCards: ShownReviewCards?
  var highlighting: Task<Void, Never>?
  /// Its height moving, as a card opens or a fold does, moves every file below.
  var onHeightChanged: (() -> Void)?

  override var isFlipped: Bool { true }

  var height: CGFloat { Self.headerHeight + diffHeight }

  /// Where the code starts across the gap views: Unified's, or Split's left.
  var codeX: CGFloat {
    let column = split?.committed ?? mainColumn
    return column.textClip.frame.minX - canvas.spanningGapViews.frame.minX
      + column.textView.textContainerOrigin.x
  }

  /// Its rows and gaps; a file with no rows but a notice, the notice's height.
  private var diffHeight: CGFloat {
    guard let slice, !slice.text.lines.isEmpty || !slice.gapItems.isEmpty else { return 0 }
    return mainColumn.textView.geometry.documentHeight(rows: slice.text.lines.count)
  }

  init(geometry: DiffRowGeometry, isSplit: Bool, scrollsWith list: NSView?) {
    if isSplit {
      let split = SplitDiffDocumentView(geometry: geometry)
      canvas = split
      self.split = split
      unified = nil
      mainColumn = split.onDisk
    } else {
      let unified = DiffDocumentView(geometry: geometry)
      canvas = unified
      self.unified = unified
      split = nil
      mainColumn = unified.column
    }
    super.init(frame: .zero)
    wantsLayer = true
    layer?.borderWidth = 1
    layer?.cornerRadius = CGFloat(UIMetrics.allChangesBoxCornerRadius)
    layer?.masksToBounds = true
    canvas.forwardsWheelTo = list
    canvas.listHeaderHeight = Self.headerHeight
    canvas.scrollView.keepsOverlayScrollers = true
    for column in [split?.committed, mainColumn].compactMap(\.self) {
      column.textView.offersChangesRotor = false
    }
    addSubview(canvas)
    addSubview(headerHost)
    unified?.onReviewCardGaps = { [weak self] gaps in
      self?.cardGaps = gaps
      self?.openGaps()
    }
    unified?.onGapViewsLaidOut = { [weak self] geometry, _ in self?.layOutItems(in: geometry) }
    split?.onSpanningGapViewsLaidOut = { [weak self] geometry, cardGaps in
      self?.gapLayer.noteCardGaps(cardGaps)
      self?.layOutItems(in: geometry)
      self?.noteHeight()
    }
  }

  required init?(coder: NSCoder) { nil }

  /// The file's header, rows and what sits between them; the text shown again
  /// only where it or the theme moved, which drops its colours: `true` then.
  @discardableResult
  func show(
    _ slice: AllChangesFileSlice,
    header: AllChangesFileHeader,
    item: @escaping (AllChangesGapItem, _ codeX: CGFloat) -> AnyView,
    itemHeight: (AllChangesGapItem) -> CGFloat,
    theme: Theme,
  ) -> Bool {
    if shownHeader != header {
      shownHeader = header
      headerHost.rootView = AnyView(header)
    }
    let border = NSColor(theme.fileTab.border).cgColor
    if layer?.borderColor != border { layer?.borderColor = border }
    let showsTextAnew =
      self.slice?.text != slice.text || self.slice?.committedText != slice.committedText
      || self.theme != theme
    if showsTextAnew {
      self.theme = theme
      if let split, let sides = slice.split {
        split.show(sides, theme: theme)
      } else {
        unified?.show(slice.text, theme: theme)
      }
    }
    self.slice = slice
    itemGaps = gapLayer.show(
      slice.gapItems,
      contentKey: theme,
      height: itemHeight,
      content: item,
      in: canvas.spanningGapViews,
    )
    openGaps()
    return showsTextAnew
  }

  /// Let go of by the list and kept for another file: what it showed of this
  /// one is dropped, the next file's shown in full.
  func forgetShownFile() {
    highlighting?.cancel()
    highlighting = nil
    shownCards = nil
    shownCommittedCards = nil
    slice = nil
    cardGaps = [:]
    gapLayer.noteCardGaps([:])
    for column in [mainColumn, split?.committed].compactMap(\.self) {
      column.textView.setSelectedRange(NSRange(location: 0, length: 0))
      column.forgetPendingScrolls()
    }
    // The next file reports its height though it match this one's: the list placed it by estimate.
    reportedHeight = 0
    gapLayer.forgetContent()
    // The header holds the whole section, its file's text with it.
    shownHeader = nil
    headerHost.rootView = AnyView(EmptyView())
    box(nil)
    canvas.scroll(to: .zero)
  }

  /// The list scrolled its rows from under the pointer: no + stays on one.
  func forgetGutterHover() {
    mainColumn.gutter.hoveredRow = nil
    split?.committed.gutter.hoveredRow = nil
  }

  /// The box around the change the arrows landed on, on both of Split's sides.
  func box(_ rows: Range<Int>?) {
    mainColumn.mirrorSteppedChange(rows)
    split?.committed.mirrorSteppedChange(rows)
  }

  private func openGaps() {
    if let split {
      split.extraRowGaps = itemGaps
    } else if let unified {
      gapLayer.noteCardGaps(cardGaps)
      unified.setRowGaps(RowGaps(cardGaps.merging(itemGaps, uniquingKeysWith: +)))
      unified.layOutGapViews()
    }
    noteHeight()
  }

  private func layOutItems(in geometry: DiffRowGeometry) {
    guard slice != nil else { return }
    split?.dividerSpan = 0...diffHeight
    gapLayer.layOut(in: geometry, width: canvas.spanningGapViews.bounds.width, codeX: codeX)
  }

  /// A view let go of, showing no file, asks the list for no layout.
  private func noteHeight() {
    needsLayout = true
    guard slice != nil, height != reportedHeight else { return }
    reportedHeight = height
    onHeightChanged?()
  }

  override func layout() {
    super.layout()
    headerHost.frame = NSRect(x: 0, y: 0, width: bounds.width, height: Self.headerHeight)
    canvas.frame = NSRect(x: 0, y: Self.headerHeight, width: bounds.width, height: diffHeight)
  }
}
