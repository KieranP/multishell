import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The All changes tab's text in SwiftUI, one `DiffDocumentView` with each
/// file's header, folds and notices in the gaps between its rows; its layout
/// goes when the tab is hidden. Rebuilt on a font change.
struct AllChangesDocumentRepresentable: NSViewRepresentable {
  /// What the view last drew, so an update redraws only what changed.
  @MainActor
  final class Coordinator {
    var theme: Theme?
    var document: AllChangesDocument?
    let paintedFindMatches: PaintedFindMatches
    let highlighter = AllChangesHighlighter()
    var highlighting: Task<Void, Never>?
    /// The files the last highlight coloured, and the scroll's hook to colour more.
    var highlightedSections: ClosedRange<Int>?
    var highlightNearbyFiles: (() -> Void)?
    let gapLayer = AllChangesGapLayer()
    var itemGaps: [Int: CGFloat] = [:]
    var cardGaps: [Int: CGFloat] = [:]
    var shownGapItems: AllChangesShownGapItems?
    var reviewCards: ShownReviewCards?
    /// A file a Changes row asked for before the view could scroll to it.
    var pendingReveal: String?
    var revealPin: AllChangesRevealPin?

    init(paintedFindMatches: PaintedFindMatches) {
      self.paintedFindMatches = paintedFindMatches
    }

    /// The cards' gaps and the items' together, the row at the top kept.
    func openGaps(on view: DiffDocumentView) {
      gapLayer.noteCardGaps(cardGaps)
      view.setRowGapsHoldingAnchor(RowGaps(cardGaps.merging(itemGaps, uniquingKeysWith: +)))
      view.layOutGapViews()
    }

    /// Its header at the top, once the view has a size and the header a place;
    /// until then it waits, and wins over the restore.
    func reveal(_ path: String, on view: DiffDocumentView) {
      view.cancelPendingRestore()
      guard view.clipHeight > 0, let document, let index = document.section(at: path),
        let header = gapLayer.documentFrame(of: document.headerItem(ofSection: index))
      else {
        pendingReveal = path
        return
      }
      pendingReveal = nil
      revealPin = AllChangesRevealPin(path: path)
      view.scroll(to: NSPoint(x: 0, y: header.minY + UIMetrics.allChangesFileGap))
      revealPin?.origin = view.scrollOrigin
    }

    /// The file at the top, its header scrolled past once the clip's top is
    /// below where the header's bar starts.
    func topFile(of view: DiffDocumentView, atRow row: Double) -> AllChangesTopFile? {
      if let pinned = revealPin?.topFile(at: view.scrollOrigin) { return pinned }
      revealPin = nil
      guard let document, let index = document.section(atRow: Int(row.rounded(.down))) else {
        return nil
      }
      let barTop = gapLayer.documentFrame(of: document.headerItem(ofSection: index)).map { header in
        header.minY + UIMetrics.allChangesFileGap
      }
      return AllChangesTopFile(
        path: document.sections[index].path,
        isHeaderScrolledPast: barTop.map { view.scrollOrigin.y > $0 } ?? false,
      )
    }
  }

  let model: AppModel
  let tab: AllChangesTab
  let document: AllChangesDocument
  let theme: Theme
  let font: FileFont
  let find: FindMatchesShown

  /// A hidden tab drops its view; its parses' spans would land on nothing.
  static func dismantleNSView(_ view: DiffDocumentView, coordinator: Coordinator) {
    coordinator.highlighting?.cancel()
  }

  func makeNSView(context: Context) -> DiffDocumentView {
    let coordinator = context.coordinator
    let tabID = tab.id
    let view = DiffDocumentView(
      geometry: DiffRowGeometry(fontFamily: font.family, fontSize: font.size)
    )
    view.leadingInset = CGFloat(UIMetrics.allChangesBoxMargin)
    // The scroller sits in the margin: over the boxes, the hosted headers covered it.
    view.scrollerMargin = CGFloat(UIMetrics.allChangesBoxMargin)
    view.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
    view.textView.onSelectionChange = { [weak model] text in
      model?.noteFileTabSelection(text, of: tabID)
    }
    view.textView.copiesSelections = { [weak coordinator] selections in
      coordinator?.document?.copy(selections: selections) ?? ""
    }
    view.onTopRowMoved = { [weak model, weak view, weak coordinator] row, x in
      guard let model, let view, let coordinator, let document = coordinator.document else {
        return
      }
      if let scroll = document.scroll(atRow: row, x: x) {
        model.noteAllChangesScrolled(tabID, to: scroll)
      }
      model.noteAllChangesTopFile(coordinator.topFile(of: view, atRow: row), in: tabID)
      coordinator.highlightNearbyFiles?()
    }
    view.onStepOriginMoved = { [weak model, weak view] in
      guard let view else { return }
      model?.noteChangeSteps(view.changeSteps, of: tabID)
    }
    view.onSteppedRowsChanged = { [weak model, weak coordinator] rows in
      let anchor = rows.flatMap { coordinator?.document?.anchor(ofChangeAt: $0) }
      model?.noteSteppedChangeAnchor(anchor, of: tabID)
    }
    view.onCommentOnRows = { [weak model, weak coordinator] start, end, side in
      guard let picked = coordinator?.document?.lineSelection(from: start, to: end, side: side)
      else { return }
      model?.openReviewComposer(on: picked.selection, ofFile: picked.path, in: tabID)
    }
    view.onReviewCardGaps = { [weak coordinator, weak view] gaps in
      guard let coordinator, let view else { return }
      coordinator.cardGaps = gaps
      coordinator.openGaps(on: view)
    }
    view.onGapViewsLaidOut = { [weak coordinator, weak view] geometry, _ in
      guard let coordinator, let view else { return }
      coordinator.gapLayer.layOut(
        in: geometry,
        y: view.scrollOrigin.y,
        x: 0,
        width: view.spanningGapViews.bounds.width - view.scrollerMargin,
        shown: 0...view.bounds.height,
        end: geometry.documentHeight(rows: view.textView.displayText.lines.count)
          - DiffRowGeometry.verticalInset,
      )
      if let path = coordinator.pendingReveal { coordinator.reveal(path, on: view) }
    }
    if let scroll = model.allChangesScroll(of: tabID), let row = document.row(of: scroll) {
      view.restore(toRow: row, x: scroll.scroll.x)
    }
    if let anchor = model.steppedChangeAnchor(of: tabID) { view.restoreSteppedChangeAnchor(anchor) }
    return view
  }

  func updateNSView(_ view: DiffDocumentView, context: Context) {
    let coordinator = context.coordinator
    let textChanged = coordinator.document?.text != document.text || coordinator.theme != theme
    coordinator.document = document
    if textChanged {
      coordinator.theme = theme
      view.show(document.text, theme: theme, anchoredBy: document)
      coordinator.highlightedSections = nil
    }
    coordinator.highlightNearbyFiles = { [weak view, weak coordinator] in
      guard let view, let coordinator else { return }
      highlightNearbyFiles(on: view, coordinator: coordinator)
    }
    highlightNearbyFiles(on: view, coordinator: coordinator)
    showGapItems(on: view, coordinator: coordinator)
    view.showReviewCards(
      ShownReviewCards(of: tab, in: document, model: model, theme: theme),
      replacing: &coordinator.reviewCards,
      model: model,
      tabID: tab.id,
    )
    if let card = model.takeReviewCardReveal(tab.id) { view.revealReviewCard(card) }
    if let shown = coordinator.paintedFindMatches.paint(
      find,
      on: view.textView,
      textChanged: textChanged,
      tint: theme.findMatchTint,
    ) {
      model.noteFileFindShown(shown, of: tab.id)
    }
    for direction in model.takeChangeStepRequests(tab.id) { view.step(toChange: direction) }
    if let path = model.takeAllChangesFileReveal(tab.id) { coordinator.reveal(path, on: view) }
    view.textView.takeKeyboard(ifAskedBy: model, for: tab.id)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(paintedFindMatches: PaintedFindMatches(resuming: model.fileFindShown(of: tab.id)))
  }

  /// The files near the clip, again only where those moved or the text did.
  private func highlightNearbyFiles(on view: DiffDocumentView, coordinator: Coordinator) {
    let nearby = AllChangesNearbySections.near(
      document,
      geometry: view.textView.geometry,
      top: view.scrollOrigin.y,
      clipHeight: view.clipHeight,
    )
    guard let nearby, nearby != coordinator.highlightedSections else { return }
    coordinator.highlightedSections = nearby
    coordinator.highlighting?.cancel()
    let tabID = tab.id
    coordinator.highlighting = Task { @MainActor [weak view, weak model, document, theme] in
      guard
        let cost = await coordinator.highlighter.highlight(
          document,
          sections: nearby,
          theme: theme,
          on: { view?.textView },
        )
      else { return }
      model?.noteAllChangesHighlighted(tabID, cost: cost)
    }
  }

  /// Hosted again only where what they show moved: an update runs on every
  /// change the tab's body reads.
  private func showGapItems(on view: DiffDocumentView, coordinator: Coordinator) {
    let shown = AllChangesShownGapItems(
      document: document,
      pendingComments: model.pendingReviewCommentCounts(in: tab.worktreeID),
      theme: theme,
    )
    guard coordinator.shownGapItems != shown else { return }
    coordinator.shownGapItems = shown
    coordinator.itemGaps = coordinator.gapLayer.show(
      document.gapItems,
      height: { item in CGFloat(model.metrics.allChangesHeight(of: item.kind)) },
      content: { item in
        AnyView(
          AllChangesGapItemView(
            model: model,
            tab: tab,
            document: document,
            item: item,
            pendingComments: shown.pendingComments,
            theme: theme,
          )
        )
      },
      boxBorder: NSColor(theme.fileTab.border).cgColor,
      in: view.spanningGapViews,
    )
    coordinator.openGaps(on: view)
  }
}
