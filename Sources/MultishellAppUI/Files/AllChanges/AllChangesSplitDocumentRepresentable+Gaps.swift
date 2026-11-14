import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// What the split's gaps hold: each file's header, folds and notices across
/// both columns, and each column's own review cards.
extension AllChangesSplitDocumentRepresentable {
  /// Hosted again only where what they show moved.
  func showGapItems(on view: SplitDiffDocumentView, coordinator: Coordinator) {
    let shown = AllChangesShownGapItems(
      document: document,
      pendingComments: model.pendingReviewCommentCounts(in: tab.worktreeID),
      theme: theme,
    )
    guard coordinator.shownGapItems != shown else { return }
    coordinator.shownGapItems = shown
    view.extraRowGaps = coordinator.gapLayer.show(
      document.gapItems,
      height: { item in
        let section = document.sections[item.section]
        guard item.kind == .wholeFile, let rows = section.fileText?.lines.count else {
          return CGFloat(model.metrics.allChangesHeight(of: item.kind))
        }
        return coordinator.wholeFiles.height(
          of: section.path,
          rows: rows,
          geometry: view.onDisk.textView.geometry,
        )
      },
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
  }

  /// Each column its own side's cards, the split opening both columns' gaps alike.
  func showReviewCards(on view: SplitDiffDocumentView, coordinator: Coordinator) {
    let columns:
      [(DiffColumn, DiffSide, ReferenceWritableKeyPath<Coordinator, ShownReviewCards?>)] = [
        (view.committed, .committed, \.committedReviewCards),
        (view.onDisk, .onDisk, \.onDiskReviewCards),
      ]
    view.placeReviewCards {
      for (column, side, shownPath) in columns {
        column.showReviewCards(
          ShownReviewCards(of: tab, in: document, model: model, theme: theme, side: side),
          replacing: &coordinator[keyPath: shownPath],
          model: model,
          tabID: tab.id,
        )
      }
    }
    if let card = model.takeReviewCardReveal(tab.id) { view.revealReviewCard(card) }
  }
}
