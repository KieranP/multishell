import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab split, its two columns locked as a file tab's are, each
/// file's header, folds and notices across both; rebuilt on a font change.
/// Find runs on the right side, the file on disk.
struct AllChangesSplitDocumentRepresentable: NSViewRepresentable {
  /// What the view last drew, so an update redraws only what changed.
  @MainActor
  final class Coordinator {
    var theme: Theme?
    var document: AllChangesDocument?
    let paintedFindMatches: PaintedFindMatches
    let highlighters = [
      AllChangesHighlighter(side: .committed), AllChangesHighlighter(side: .onDisk),
    ]
    var highlighting: Task<Void, Never>?
    /// The files the last highlight coloured, and the scroll's hook to colour more.
    var highlightedSections: ClosedRange<Int>?
    var highlightNearbyFiles: (() -> Void)?
    let gapLayer = AllChangesGapLayer()
    let wholeFiles = AllChangesWholeFileLayer()
    var wholeFileHost: AllChangesWholeFileHost?
    /// Hosts the gap items again with new heights, as a whole file's cards move it.
    var reshowGapItems: (() -> Void)?
    var shownGapItems: AllChangesShownGapItems?
    var committedReviewCards: ShownReviewCards?
    var onDiskReviewCards: ShownReviewCards?
    /// A file a Changes row asked for before the view could scroll to it.
    var pendingReveal: String?
    var revealPin: AllChangesRevealPin?

    init(paintedFindMatches: PaintedFindMatches) {
      self.paintedFindMatches = paintedFindMatches
    }

    /// Where a header's bar starts in the document, from its frame over the
    /// columns, which sits the columns' scroll above it.
    private func headerBarTop(ofSection index: Int, in view: SplitDiffDocumentView) -> CGFloat? {
      guard let document,
        let frame = gapLayer.documentFrame(of: document.headerItem(ofSection: index))
      else { return nil }
      return frame.minY + UIMetrics.allChangesFileGap
    }

    /// From the first file's box to the last's end, where the columns' divider
    /// shows; none with no files.
    func boxesSpan(ending end: CGFloat) -> ClosedRange<CGFloat> {
      guard let document, !document.sections.isEmpty,
        let header = gapLayer.parentFrame(of: document.headerItem(ofSection: 0))
      else { return 0...0 }
      let top = header.minY + UIMetrics.allChangesFileGap
      return top...max(top, end)
    }

    /// Its header at the top, once the view has a size and the header a place.
    func reveal(_ path: String, on view: SplitDiffDocumentView) {
      view.committed.cancelPendingRestore()
      view.onDisk.cancelPendingRestore()
      guard view.onDisk.clipHeight > 0, let index = document?.section(at: path),
        let top = headerBarTop(ofSection: index, in: view)
      else {
        pendingReveal = path
        return
      }
      pendingReveal = nil
      revealPin = AllChangesRevealPin(path: path)
      view.onDisk.scroll(to: NSPoint(x: 0, y: top))
      revealPin?.origin = view.onDisk.scrollOrigin
    }

    func topFile(of view: SplitDiffDocumentView, atRow row: Double) -> AllChangesTopFile? {
      if let pinned = revealPin?.topFile(at: view.onDisk.scrollOrigin) { return pinned }
      revealPin = nil
      guard let document else { return nil }
      // A file shown whole has no rows, so the row at the top would be the next file's.
      let wholeAtTop = document.gapItems.first { item in
        item.kind == .wholeFile
          && (gapLayer.parentFrame(of: item).map { $0.minY <= 0 && $0.maxY > 0 } ?? false)
      }
      if let wholeAtTop {
        return AllChangesTopFile(
          path: document.sections[wholeAtTop.section].path,
          isHeaderScrolledPast: true,
        )
      }
      guard let index = document.section(atRow: Int(row.rounded(.down))) else { return nil }
      let barTop = headerBarTop(ofSection: index, in: view)
      return AllChangesTopFile(
        path: document.sections[index].path,
        isHeaderScrolledPast: barTop.map { view.onDisk.scrollOrigin.y > $0 } ?? false,
      )
    }
  }

  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument
  let split: SplitDiff
  let theme: Theme
  let font: FileFont
  let find: FindMatchesShown

  /// A hidden tab drops its view; its parses' spans would land on nothing.
  static func dismantleNSView(_ view: SplitDiffDocumentView, coordinator: Coordinator) {
    coordinator.highlighting?.cancel()
    coordinator.wholeFiles.cancelHighlighting()
  }

  /// Both columns act as one: the left's wheel turns the right, which the lock
  /// follows, so the left never scrolls, bounces or clamps on its own.
  private func setUpColumns(of view: SplitDiffDocumentView, coordinator: Coordinator) {
    let tabID = tab.id
    view.horizontalInset = CGFloat(UIMetrics.allChangesBoxMargin)
    view.committed.showsVerticalScroller = false
    view.committed.forwardsScrollWheel = view.onDisk.textView.enclosingScrollView
    for column in [view.committed, view.onDisk] {
      column.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
      column.onCommentOnRows = { [weak model, weak coordinator] start, end, side in
        guard let picked = coordinator?.document?.lineSelection(from: start, to: end, side: side)
        else { return }
        model?.openReviewComposer(on: picked.selection, ofFile: picked.path, in: tabID)
      }
    }
  }

  func makeNSView(context: Context) -> SplitDiffDocumentView {
    let coordinator = context.coordinator
    let tabID = tab.id
    let view = SplitDiffDocumentView(
      geometry: DiffRowGeometry(fontFamily: font.family, fontSize: font.size)
    )
    setUpColumns(of: view, coordinator: coordinator)
    view.onDisk.textView.onSelectionChange = { [weak model] text in
      model?.noteFileTabSelection(text, of: tabID)
    }
    view.onDisk.onTopRowMoved = { [weak model, weak view, weak coordinator] row, x in
      guard let model, let view, let coordinator, let document = coordinator.document else {
        return
      }
      if let scroll = document.scroll(atRow: row, x: x) {
        model.noteAllChangesScrolled(tabID, to: scroll)
      }
      model.noteAllChangesTopFile(coordinator.topFile(of: view, atRow: row), in: tabID)
      coordinator.highlightNearbyFiles?()
    }
    view.onStepsCounted = { [weak model] steps in model?.noteChangeSteps(steps, of: tabID) }
    view.onSteppedChangeAnchorChanged = { [weak model] anchor in
      model?.noteSteppedChangeAnchor(anchor, of: tabID)
    }
    view.onSpanningGapViewsLaidOut = { [weak coordinator, weak view] geometry, y, cardGaps in
      guard let coordinator, let view else { return }
      coordinator.gapLayer.noteCardGaps(cardGaps)
      let end =
        geometry.documentHeight(rows: view.onDisk.textView.displayText.lines.count)
        - DiffRowGeometry.verticalInset
      coordinator.gapLayer.layOut(
        in: geometry,
        y: y,
        x: view.horizontalInset,
        width: view.bounds.width - view.horizontalInset * 2,
        shown: 0...view.bounds.height,
        end: end,
      )
      view.dividerSpan = coordinator.boxesSpan(ending: end - y)
      if let document = coordinator.document, let host = coordinator.wholeFileHost {
        coordinator.wholeFiles.layOut(
          document,
          frames: coordinator.gapLayer.parentFrame(of:),
          in: view.spanningGapViews,
          scrollsWith: view.onDisk.textView.enclosingScrollView,
          gutterWidth: view.committed.gutter.frame.width,
          host: host,
        )
      }
      if let path = coordinator.pendingReveal { coordinator.reveal(path, on: view) }
    }
    if let scroll = model.allChangesScroll(of: tabID), let row = document.row(of: scroll) {
      view.restore(toRow: row, x: scroll.scroll.x)
    }
    if let anchor = model.steppedChangeAnchor(of: tabID) { view.restoreSteppedChangeAnchor(anchor) }
    return view
  }

  func updateNSView(_ view: SplitDiffDocumentView, context: Context) {
    let coordinator = context.coordinator
    let textChanged = coordinator.document?.split != split || coordinator.theme != theme
    coordinator.document = document
    coordinator.wholeFileHost = AllChangesWholeFileHost(
      model: model,
      tab: tab,
      theme: theme,
      geometry: view.onDisk.textView.geometry,
    )
    coordinator.wholeFiles.onHeightChanged = { [weak coordinator] in coordinator?.reshowGapItems?()
    }
    coordinator.reshowGapItems = { [weak coordinator, weak view] in
      guard let coordinator, let view else { return }
      coordinator.shownGapItems = nil
      showGapItems(on: view, coordinator: coordinator)
    }
    if textChanged {
      coordinator.theme = theme
      view.show(split, theme: theme, anchoredBy: document)
      coordinator.highlightedSections = nil
    }
    coordinator.highlightNearbyFiles = { [weak view, weak coordinator] in
      guard let view, let coordinator else { return }
      highlightNearbyFiles(on: view, coordinator: coordinator)
    }
    highlightNearbyFiles(on: view, coordinator: coordinator)
    showGapItems(on: view, coordinator: coordinator)
    if let shown = coordinator.paintedFindMatches.paint(
      find,
      on: view.onDisk.textView,
      textChanged: textChanged,
      tint: theme.findMatchTint,
    ) {
      model.noteFileFindShown(shown, of: tab.id)
    }
    for direction in model.takeChangeStepRequests(tab.id) { view.step(toChange: direction) }
    showReviewCards(on: view, coordinator: coordinator)
    if let path = model.takeAllChangesFileReveal(tab.id) { coordinator.reveal(path, on: view) }
    view.onDisk.textView.takeKeyboard(ifAskedBy: model, for: tab.id)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(paintedFindMatches: PaintedFindMatches(resuming: model.fileFindShown(of: tab.id)))
  }

  /// The files near the clip, again only where those moved or the text did.
  private func highlightNearbyFiles(on view: SplitDiffDocumentView, coordinator: Coordinator) {
    let nearby = AllChangesNearbySections.near(
      document,
      geometry: view.onDisk.textView.geometry,
      top: view.onDisk.scrollOrigin.y,
      clipHeight: view.onDisk.clipHeight,
    )
    guard let nearby, nearby != coordinator.highlightedSections else { return }
    coordinator.highlightedSections = nearby
    coordinator.highlighting?.cancel()
    let tabID = tab.id
    coordinator.highlighting = Task { @MainActor [weak view, weak model, document, theme] in
      var cost = Duration.zero
      let columns = [\SplitDiffDocumentView.committed, \.onDisk]
      for (highlighter, column) in zip(coordinator.highlighters, columns) {
        guard
          let columnCost = await highlighter.highlight(
            document,
            sections: nearby,
            theme: theme,
            on: { view?[keyPath: column].textView },
          )
        else { return }
        cost += columnCost
      }
      model?.noteAllChangesHighlighted(tabID, cost: cost)
    }
  }
}
