import AppKit
import MultishellAppCore
import MultishellCore
import MultishellHighlight

/// What the list's representable keeps between updates: the document and its
/// slices, the parses, the boxed change and the find matches painted.
@MainActor
final class AllChangesListCoordinator {
  /// The latest update's, which the list's closures call: the one that made
  /// the list holds the document and theme it was made with.
  var representable: AllChangesListRepresentable?
  private(set) var document: AllChangesDocument?
  /// Comments to send by path, counted once an update for every header shown.
  var pendingComments: [String: Int] = [:]
  var theme: Theme?
  /// Each document's per-file parts, cut as their views are built.
  private var slices: [Int: AllChangesFileSlice] = [:]
  private var unreadSections: Set<Int> = []
  private var parses = AllChangesHighlightCache()
  /// The tab's saved scroll, put back once the list has a size.
  var savedScroll: AllChangesScroll?
  /// Where the saved scroll left the list in its file while that file waits
  /// to be read; the list found elsewhere was scrolled away.
  var offsetIntoUnreadSavedFile: CGFloat?
  var pendingReveal: String?
  /// Where a Changes click left the list, its file lit there whatever is at the top.
  var scrollYLeftByReveal: CGFloat?
  /// The change the arrows last landed on, boxed in its file's view.
  private var boxed: AllChangesFileRow?
  private var paintedFind: FindMatchesShown?
  /// Every change's file and row there, in list order, cut once a document.
  private var stops: [AllChangesFileRow]?
  private var findTint = NSColor.clear

  func noteDocument(_ document: AllChangesDocument) {
    boxed = boxed.flatMap { carried($0, to: document) }
    self.document = document
    slices = [:]
    stops = nil
    unreadSections = document.unreadSections
    parses.keepOnly { key, text in
      guard let index = document.section(at: key.path) else { return false }
      let section = document.sections[index]
      return (key.side == .committed ? section.fileCommittedText : section.fileText) == text
    }
  }

  /// The boxed change in a new document, by its lines as a file tab keeps its
  /// box: rows move as folds open or files come and go above.
  private func carried(
    _ stop: AllChangesFileRow,
    to next: AllChangesDocument,
  ) -> AllChangesFileRow? {
    guard let document, document.sections.indices.contains(stop.section),
      let text = slice(stop.section)?.text, let rows = text.change(containing: stop.row),
      let anchor = text.anchor(ofChangeAt: rows),
      let section = next.section(at: document.sections[stop.section].path),
      let moved = next.slice(ofSection: section).text.change(at: anchor)
    else { return nil }
    return AllChangesFileRow(section: section, row: moved.lowerBound)
  }

  func slice(_ index: Int) -> AllChangesFileSlice? {
    guard let document, document.sections.indices.contains(index) else { return nil }
    if let cached = slices[index] { return cached }
    let slice = document.slice(ofSection: index)
    slices[index] = slice
    return slice
  }

  /// A file's height before its view measures: its header, rows and the
  /// folds and notices between them; cards come once measured.
  func estimate(_ index: Int, geometry: DiffRowGeometry, metrics: UIMetrics) -> CGFloat {
    guard let document, document.sections.indices.contains(index) else { return 0 }
    let rows = document.sections[index].rows.count
    let items = document.gapItems(ofSection: index)
    let gaps = items.reduce(0) { $0 + CGFloat(metrics.allChangesHeight(of: $1.kind)) }
    guard rows > 0 || !items.isEmpty else { return AllChangesFileView.headerHeight }
    var rowsAlone = geometry
    rowsAlone.rowGaps = .empty
    return AllChangesFileView.headerHeight + rowsAlone.documentHeight(rows: rows) + gaps
  }

  /// Colours a built file from its parses, kept by path, a fold opening or a
  /// scroll back parsing nothing again: Split's left from the committed side.
  func highlight(_ view: AllChangesFileView, theme: Theme) {
    guard let document, let slice = view.slice else { return }
    let section = document.sections[slice.section]
    view.highlighting?.cancel()
    view.highlighting = Task { @MainActor [weak self, weak view] in
      var sides: [(DiffSide?, DiffDisplayText?, DiffColumn?)] = [
        (nil, section.fileText, view?.mainColumn)
      ]
      if slice.committedText != nil {
        sides.append((.committed, section.fileCommittedText, view?.split?.committed))
      }
      for (side, fileText, column) in sides {
        guard let fileText, let column else { continue }
        let key = AllChangesHighlightKey(path: section.path, side: side)
        let spans: [HighlightSpan]
        if let cached = self?.parses.spans(of: key, for: fileText) {
          spans = cached
        } else {
          spans = await DiffHighlighting.spans(for: fileText, path: section.path)
          guard !Task.isCancelled else { return }
          self?.parses.keep(spans, of: key, for: fileText)
        }
        // The document the slice was cut from maps them: a newer one may hold fewer files.
        let runs = document.sliceSpans(spans, ofSection: slice.section, side: side)
        let text = side == .committed ? slice.committedText ?? slice.text : slice.text
        _ = await column.textView.applyHighlights(runs, for: text, theme: theme)
        guard !Task.isCancelled else { return }
      }
    }
  }

  /// A built file's view shown its share of the boxed change and the matches.
  func dress(_ view: AllChangesFileView, at index: Int) {
    let rows = boxed.flatMap { stop in
      stop.section == index ? view.slice?.text.change(containing: stop.row) : nil
    }
    view.box(rows)
    // Each update dresses every built file; one whose matches stand is not redrawn.
    let textView = view.mainColumn.textView
    let matches = matches(ofSection: index)
    guard textView.findMatchPaint.matches != matches || textView.findMatchPaint.tint != findTint
    else { return }
    textView.findMatchPaint = (matches, findTint)
    textView.needsDisplay = true
  }

  /// Where a row of a file starts in the list: its view's place once built,
  /// else the rows above it at the row height.
  private func top(
    ofRow row: Int,
    inFile index: Int,
    on list: AllChangesListView,
    geometry: DiffRowGeometry,
  )
    -> CGFloat?
  {
    guard let fileTop = list.top(ofFile: index) else { return nil }
    let intoRows =
      list.file(at: index)?.mainColumn.textView.geometry.top(ofRow: row)
      ?? geometry.verticalInset + CGFloat(row) * geometry.rowHeight
    return fileTop + AllChangesFileView.headerHeight + intoRows
  }

  /// `row` put `offset` below the clip's top. Twice: the first scroll builds its
  /// file, whose own geometry then places the row exactly.
  func scroll(
    to row: AllChangesFileRow,
    below offset: CGFloat,
    on list: AllChangesListView,
    geometry: DiffRowGeometry,
  ) {
    for _ in 0..<2 {
      guard let top = top(of: row, on: list, geometry: geometry) else { return }
      list.scroll(toY: top - offset)
    }
  }

  /// Where a step or reveal puts its change: under the sticky header, a few
  /// rows of context above it.
  func offsetAboveAChange(on list: AllChangesListView, geometry: DiffRowGeometry) -> CGFloat {
    let header = AllChangesFileView.headerHeight
    let rows = geometry.rowsAboveAChange(inClipOf: list.clipHeight - header)
    return header + CGFloat(rows) * geometry.rowHeight
  }

  /// Where a row starts: in a file still to be read, at its header.
  private func top(
    of row: AllChangesFileRow,
    on list: AllChangesListView,
    geometry: DiffRowGeometry,
  ) -> CGFloat? {
    guard !isUnread(row.section) else { return list.top(ofFile: row.section) }
    return top(ofRow: row.row, inFile: row.section, on: list, geometry: geometry)
  }

  func isUnread(_ section: Int) -> Bool {
    unreadSections.contains(section)
  }

  private func steps(on list: AllChangesListView, geometry: DiffRowGeometry) -> AllChangesSteps {
    AllChangesSteps(placed(allStops(), on: list, geometry: geometry))
  }

  /// The first and last changes alone, enough to say whether either way has one:
  /// placing every change on each scroll took two thirds of it.
  func outermostSteps(on list: AllChangesListView, geometry: DiffRowGeometry) -> AllChangesSteps {
    let stops = allStops()
    let ends = [stops.first, stops.last].compactMap(\.self)
    return AllChangesSteps(placed(ends, on: list, geometry: geometry))
  }

  private func allStops() -> [AllChangesFileRow] {
    if let stops { return stops }
    let cut = document?.changeStops ?? []
    stops = cut
    return cut
  }

  private func placed(
    _ stops: [AllChangesFileRow],
    on list: AllChangesListView,
    geometry: DiffRowGeometry,
  ) -> [AllChangesSteps.Placed] {
    stops.compactMap { stop in
      top(of: stop, on: list, geometry: geometry).map { top in
        AllChangesSteps.Placed(stop: stop, top: Double(top))
      }
    }
  }

  func stepOrigin(on list: AllChangesListView, geometry: DiffRowGeometry) -> AllChangesStepOrigin {
    AllChangesStepOrigin(
      boxedTop: boxed.flatMap { top(of: $0, on: list, geometry: geometry) }.map(Double.init),
      clipTop: Double(list.scrollY),
      clipHeight: Double(list.clipHeight),
    )
  }

  /// The next or previous change across the files, a few rows under the top
  /// and boxed.
  func step(_ direction: CycleDirection, on list: AllChangesListView, geometry: DiffRowGeometry) {
    let origin = stepOrigin(on: list, geometry: geometry)
    guard let stop = steps(on: list, geometry: geometry).stop(direction, from: origin) else {
      return
    }
    let previous = boxed
    boxed = stop
    if let previous, let view = list.file(at: previous.section) {
      dress(view, at: previous.section)
    }
    scroll(
      to: stop,
      below: offsetAboveAChange(on: list, geometry: geometry),
      on: list,
      geometry: geometry,
    )
    if let view = list.file(at: stop.section) { dress(view, at: stop.section) }
  }

  /// The matches in one file's view, by its own offsets.
  private func matches(ofSection index: Int) -> [Range<Int>] {
    guard let document, let find = paintedFind, document.sections.indices.contains(index) else {
      return []
    }
    let rows = document.sections[index].rows
    guard !rows.isEmpty else { return [] }
    let text = document.text
    let start = text.rowStarts[rows.lowerBound]
    let end = text.range(ofRow: rows.upperBound - 1).upperBound
    let first = find.matches.partitioningIndex { $0.upperBound > start }
    return find.matches[first...].prefix { $0.lowerBound < end }.map { $0.shifted(by: -start) }
  }

  /// Paints `find` in each built file and brings a moved selection into view;
  /// what the model should keep, or `nil` where nothing changed.
  func paint(
    _ find: FindMatchesShown,
    on list: AllChangesListView,
    tint: NSColor,
    geometry: DiffRowGeometry,
    textChanged: Bool,
  ) -> FileFindShown? {
    guard textChanged || paintedFind != find else { return nil }
    let previous = paintedFind
    paintedFind = find
    findTint = tint
    for (index, view) in list.builtFiles { dress(view, at: index) }
    guard find.movesSelection(from: previous), let document, let selected = find.selected,
      find.matches.indices.contains(selected)
    else { return find.shown }
    let match = find.matches[selected]
    let row = document.text.row(atOffset: match.lowerBound)
    guard let section = document.section(atRow: row) else { return find.shown }
    let fileRow = row - document.sections[section].rows.lowerBound
    scroll(
      to: AllChangesFileRow(section: section, row: fileRow),
      below: list.clipHeight / 3,
      on: list,
      geometry: geometry,
    )
    if let view = list.file(at: section) {
      let start = document.text.rowStarts[document.sections[section].rows.lowerBound]
      view.mainColumn.textView.setSelectedRange(NSRange(match.shifted(by: -start)))
    }
    return find.shown
  }
}
