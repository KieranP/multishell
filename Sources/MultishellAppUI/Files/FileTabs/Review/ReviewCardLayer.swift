import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The review cards over a file tab's text, each hosted in the gap opened
/// under its last row, measured at the clip's width; see files/review-comments.md.
@MainActor
final class ReviewCardLayer {
  private static let sideMargin: CGFloat = 16
  private static let verticalMargin: CGFloat = 6

  private var hosts: [ReviewCardPlacement.CardID: NSHostingController<AnyView>] = [:]
  private var placements: [ReviewCardPlacement] = []
  private var heights: [ReviewCardPlacement.CardID: CGFloat] = [:]
  private var measuredWidth: CGFloat = 0

  private var cardWidth: CGFloat { max(0, measuredWidth - Self.sideMargin * 2) }

  /// Hosts each card in `textView`, measured at `clipWidth`, and returns the
  /// gap each card's row needs. A card no longer placed is taken out.
  func show(
    _ placements: [ReviewCardPlacement],
    content: (ReviewCardPlacement) -> AnyView,
    in textView: NSView,
    clipWidth: CGFloat,
  ) -> [Int: CGFloat] {
    self.placements = placements
    measuredWidth = clipWidth
    let shown = Set(placements.map(\.id))
    for (id, host) in hosts where !shown.contains(id) {
      host.view.removeFromSuperview()
      hosts[id] = nil
      heights[id] = nil
    }
    for placement in placements {
      let host = hosts[placement.id] ?? makeHost(in: textView)
      host.rootView = content(placement)
      hosts[placement.id] = host
    }
    return measure()
  }

  /// `nil` where the width is what the cards were measured at.
  func remeasure(atClipWidth clipWidth: CGFloat) -> [Int: CGFloat]? {
    guard clipWidth != measuredWidth, !placements.isEmpty else { return nil }
    measuredWidth = clipWidth
    return measure()
  }

  /// At the clip's left edge, so a sideways scroll keeps a card in view, and
  /// stacked down the gap in the order placed.
  func layOut(in geometry: DiffRowGeometry, scrolledTo x: CGFloat) {
    var nextTop: [Int: CGFloat] = [:]
    for placement in placements {
      guard let host = hosts[placement.id], let height = heights[placement.id] else { continue }
      let row = placement.rows.upperBound
      let top = nextTop[row] ?? geometry.gapTop(afterRow: row) + Self.verticalMargin
      host.view.frame = NSRect(x: x + Self.sideMargin, y: top, width: cardWidth, height: height)
      nextTop[row] = top + height + Self.verticalMargin
    }
  }

  /// The rows of the card, or of the composer editing the comment asked for.
  func rows(of card: ReviewCardPlacement.CardID) -> ClosedRange<Int>? {
    placements.first { $0.stands(for: card) }?.rows
  }

  /// The card with its margins, not the cards stacked with it in its gap, once laid out.
  func span(of card: ReviewCardPlacement.CardID) -> ClosedRange<CGFloat>? {
    guard let placement = placements.first(where: { $0.stands(for: card) }),
      let frame = hosts[placement.id]?.view.frame
    else { return nil }
    return (frame.minY - Self.verticalMargin)...(frame.maxY + Self.verticalMargin)
  }

  private func makeHost(in textView: NSView) -> NSHostingController<AnyView> {
    let host = NSHostingController(rootView: AnyView(EmptyView()))
    host.sizingOptions = []
    host.view.wantsLayer = true
    // TextKit 2 adds its fragments' views as it lays out; the cards stay over them.
    host.view.layer?.zPosition = 1
    textView.addSubview(host.view)
    return host
  }

  /// Nothing before the clip has a width: cards measured at zero open tall gaps,
  /// each laying out the whole text, only for the width to undo them.
  private func measure() -> [Int: CGFloat] {
    guard measuredWidth > 0 else { return [:] }
    var gaps: [Int: CGFloat] = [:]
    let proposal = CGSize(width: cardWidth, height: .greatestFiniteMagnitude)
    for placement in placements {
      guard let host = hosts[placement.id] else { continue }
      let height = host.sizeThatFits(in: proposal).height.rounded(.up)
      heights[placement.id] = height
      gaps[placement.rows.upperBound, default: Self.verticalMargin] += height + Self.verticalMargin
    }
    return gaps
  }
}
