import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

extension DiffDocumentView {
  func showReviewCards(
    _ placements: [ReviewCardPlacement],
    content: (ReviewCardPlacement) -> AnyView,
  ) {
    let gaps = reviewCards.show(
      placements,
      content: content,
      in: textView,
      clipWidth: clipWidth,
    )
    openReviewCardGaps(gaps)
    layOutGapViews()
  }

  /// Placed again only where what they show moved since `last`: an update runs on
  /// every change the tab's body reads.
  func showReviewCards(
    _ shown: ShownReviewCards,
    replacing last: inout ShownReviewCards?,
    model: AppModel,
    tabID: ReviewTabID,
  ) {
    guard last != shown else { return }
    last = shown
    showReviewCards(shown.placements) { placement in
      AnyView(ReviewCard(placement: placement, model: model, tabID: tabID, theme: shown.theme))
    }
  }

  func openReviewCardGaps(_ gaps: [Int: CGFloat]) {
    if let onReviewCardGaps {
      onReviewCardGaps(gaps)
    } else {
      setRowGapsHoldingAnchor(RowGaps(gaps))
    }
  }

  /// A comment Review asked for: its lines near the top, its card in view below. A
  /// composer: scrolled only as far as shows it. Before a size, once there is one.
  func revealReviewCard(_ card: ReviewCardPlacement.CardID) {
    // A card not placed, hidden by the scope, leaves the tab where it was left.
    guard let rows = reviewCards.rows(of: card) else { return }
    guard clipHeight > 0 else {
      pendingCardReveal = card
      cancelPendingRestore()
      needsLayout = true
      return
    }
    let geometry = textView.geometry
    // Its own span, as cards under one row stack.
    let span =
      reviewCards.span(of: card)
      ?? geometry.gapTop(afterRow: rows.upperBound)...geometry.top(ofRow: rows.upperBound + 1)
    if case .composer = card {
      // Its top shown where it is taller than the clip, the lines it quotes not chased.
      let shown = scrollOrigin.y
      let y = min(span.lowerBound, max(shown, span.upperBound - clipHeight))
      if y != shown { scroll(to: NSPoint(x: scrollOrigin.x, y: y)) }
      return
    }
    let linesAtTop = geometry.scrollOffset(
      putting: rows.lowerBound,
      rowsBelowTop: geometry.rowsAboveAChange(inClipOf: clipHeight),
    )
    // A range taller than the clip gives way to the card under its last line, and a
    // card taller than the clip to its own top, where its label and buttons are.
    let y = min(span.lowerBound, max(linesAtTop, span.upperBound - clipHeight))
    scroll(to: NSPoint(x: scrollOrigin.x, y: y))
  }
}
