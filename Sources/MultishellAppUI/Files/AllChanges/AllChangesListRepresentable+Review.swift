import AppKit
import MultishellAppCore
import MultishellCore

/// Review in the All changes list: each file's cards, and a comment Review
/// picked brought into view.
extension AllChangesListRepresentable {
  /// Each column its own side's cards; a file shown whole its own Unified rows'.
  func showReviewCards(on view: AllChangesFileView, at index: Int) {
    guard let slice = view.slice else { return }
    let section = document.sections[index]
    if let split = view.split {
      split.placeReviewCards {
        split.committed.showReviewCards(
          ShownReviewCards(
            of: tab,
            in: document,
            section: index,
            model: model,
            theme: theme,
            side: .committed,
          ),
          replacing: &view.shownCommittedCards,
          model: model,
          tabID: tab.id,
        )
        split.onDisk.showReviewCards(
          ShownReviewCards(
            of: tab,
            in: document,
            section: index,
            model: model,
            theme: theme,
            side: .onDisk,
          ),
          replacing: &view.shownCards,
          model: model,
          tabID: tab.id,
        )
      }
      return
    }
    let shown =
      section.isShownWhole
      ? ShownReviewCards(
        of: tab,
        onWholeFile: section.path,
        in: slice.text.lines,
        model: model,
        theme: theme,
      )
      : ShownReviewCards(of: tab, in: document, section: index, model: model, theme: theme)
    view.mainColumn.showReviewCards(
      shown,
      replacing: &view.shownCards,
      model: model,
      tabID: tab.id,
    )
  }

  /// A comment Review picked: its lines a few rows under the top, its card below;
  /// a composer, as in a file tab, scrolled only as far as shows it.
  func revealReviewCard(
    _ card: ReviewCardPlacement.CardID,
    on list: AllChangesListView,
    coordinator: Coordinator,
  ) {
    guard let stop = model.reviewCardRow(card, of: tab, in: document) else { return }
    coordinator.savedScroll = nil
    if case .composer = card, let span = shownSpan(of: card, in: stop.section, on: list) {
      let belowHeader = span.lowerBound - AllChangesFileView.headerHeight
      list.scroll(toY: min(belowHeader, max(list.scrollY, span.upperBound - list.clipHeight)))
      return
    }
    let geometry = self.geometry
    let above = coordinator.offsetAboveAChange(on: list, geometry: geometry)
    coordinator.scroll(to: stop, below: above, on: list, geometry: geometry)
  }

  /// Where a card sits in the list, in whichever column of its built file holds it.
  private func shownSpan(
    of card: ReviewCardPlacement.CardID,
    in index: Int,
    on list: AllChangesListView,
  ) -> ClosedRange<CGFloat>? {
    guard let view = list.file(at: index), let fileTop = list.top(ofFile: index),
      let span = [view.mainColumn, view.split?.committed].lazy
        .compactMap({ $0?.reviewCards.span(of: card) }).first
    else { return nil }
    let top = fileTop + AllChangesFileView.headerHeight
    return (top + span.lowerBound)...(top + span.upperBound)
  }
}
