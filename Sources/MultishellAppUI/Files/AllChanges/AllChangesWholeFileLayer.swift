import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// In Split, each file only added or removed shown Unified across both columns:
/// a view of its own in its gap, hosted only while near the clip and only as
/// tall as the part on screen, scrolled within to follow the columns.
@MainActor
final class AllChangesWholeFileLayer {
  /// One file's view and what it shows.
  private final class Shown {
    let view: DiffDocumentView
    var text: DiffDisplayText?
    var theme: Theme?
    var reviewCards: ShownReviewCards?
    var highlighting: Task<Void, Never>?

    init(view: DiffDocumentView) {
      self.view = view
    }
  }

  private var shown: [String: Shown] = [:]
  /// Each file's rows' height with its cards' gaps, as its view last measured,
  /// without the view's insets, so its first row sits under the header as in Unified.
  private(set) var heights: [String: CGFloat] = [:]
  /// A file's height moving, as a card opens in it, moves every gap below.
  var onHeightChanged: (() -> Void)?

  /// The height a file takes before its view has measured its cards: its rows
  /// alone, `geometry`'s own gaps being the columns' and none of the file's.
  func height(of path: String, rows: Int, geometry: DiffRowGeometry) -> CGFloat {
    heights[path] ?? CGFloat(rows) * geometry.rowHeight
  }

  /// Each whole file's view placed over the part of its gap `parent` shows;
  /// one off screen is let go of.
  func layOut(
    _ document: AllChangesDocument,
    frames: (AllChangesGapItem) -> NSRect?,
    in parent: NSView,
    scrollsWith scroller: NSView?,
    gutterWidth: CGFloat,
    host: AllChangesWholeFileHost,
  ) {
    var near: Set<String> = []
    for item in document.gapItems where item.kind == .wholeFile {
      let section = document.sections[item.section]
      guard let fileText = section.fileText, let frame = frames(item) else { continue }
      let visible = frame.intersection(parent.bounds)
      guard !visible.isNull, visible.height > 0 else { continue }
      near.insert(section.path)
      let entry = shown[section.path] ?? makeShown(for: section.path, in: parent, scroller, host)
      shown[section.path] = entry
      show(fileText, of: section.path, in: entry, host: host)
      entry.view.minimumGutterWidth = gutterWidth
      if entry.view.frame != visible { entry.view.frame = visible }
      entry.view.layoutSubtreeIfNeeded()
      let top = visible.minY - frame.minY + DiffRowGeometry.verticalInset
      entry.view.scroll(to: NSPoint(x: entry.view.scrollOrigin.x, y: top))
    }
    for (path, entry) in shown where !near.contains(path) {
      entry.highlighting?.cancel()
      entry.view.removeFromSuperview()
      shown[path] = nil
    }
    heights = heights.filter { path, _ in document.section(at: path) != nil }
  }

  func cancelHighlighting() {
    for entry in shown.values { entry.highlighting?.cancel() }
  }

  private func makeShown(
    for path: String,
    in parent: NSView,
    _ scroller: NSView?,
    _ host: AllChangesWholeFileHost,
  ) -> Shown {
    let view = DiffDocumentView(geometry: host.geometry)
    view.forwardsScrollWheel = scroller
    let model = host.model
    let tabID = host.tab.id
    view.textView.onFocus = { [weak model] in model?.noteFileTabFocused(tabID) }
    view.onCommentOnLines = { [weak model] lines in
      model?.openReviewComposer(on: lines, ofFile: path, in: tabID)
    }
    let entry = Shown(view: view)
    view.onReviewCardGaps = { [weak self, weak view] gaps in
      guard let self, let view else { return }
      view.setRowGaps(RowGaps(gaps))
      let height =
        view.textView.geometry.documentHeight(rows: view.textView.displayText.lines.count)
        - DiffRowGeometry.verticalInset * 2
      guard heights[path] != height else { return }
      heights[path] = height
      // A turn later: the gaps it moves lay this view out again, mid card pass.
      Task { @MainActor [weak self] in self?.onHeightChanged?() }
    }
    parent.addSubview(view)
    return entry
  }

  private func show(
    _ text: DiffDisplayText,
    of path: String,
    in entry: Shown,
    host: AllChangesWholeFileHost,
  ) {
    if entry.text != text || entry.theme != host.theme {
      entry.text = text
      entry.theme = host.theme
      entry.view.show(text, theme: host.theme)
      entry.highlighting?.cancel()
      let theme = host.theme
      entry.highlighting = Task { @MainActor [weak view = entry.view] in
        _ = await DiffTextView.highlight(text, path: path, theme: theme, on: { view?.textView })
      }
    }
    var shownCards = entry.reviewCards
    entry.view.showReviewCards(
      ShownReviewCards(
        of: host.tab,
        onWholeFile: path,
        in: text.lines,
        model: host.model,
        theme: host.theme,
      ),
      replacing: &shownCards,
      model: host.model,
      tabID: host.tab.id,
    )
    entry.reviewCards = shownCards
  }
}
