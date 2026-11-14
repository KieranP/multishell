import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DiffDocumentViewReviewCardsTests {
  private static let cardHeight: CGFloat = 70

  private static func placement(after row: Int) -> ReviewCardPlacement {
    let comment = ReviewComment(
      path: "a.swift",
      side: .onDisk,
      scope: .modified,
      lines: (row + 1)...(row + 1),
      quote: ["line \(row)"],
      text: "Fix it.",
    )
    return ReviewCardPlacement(card: .comment(comment, isSelected: false), rows: row...row)
  }

  private static func composerPlacement(after row: Int) -> ReviewCardPlacement {
    let composer = ReviewComposer(
      path: "a.txt",
      side: .onDisk,
      lines: (row + 1)...(row + 1),
      quote: ["line \(row)"],
      scope: .modified,
      editing: nil,
    )
    return ReviewCardPlacement(card: .composer(composer), rows: row...row)
  }

  private static func card(_ placement: ReviewCardPlacement) -> AnyView {
    AnyView(Color.clear.frame(height: cardHeight))
  }

  @Test func aCardOpensAGapUnderItsRowAndSitsInIt() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<40).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let rowBelowBefore = view.textView.geometry.top(ofRow: 6)

    view.showReviewCards([Self.placement(after: 5)], content: Self.card)
    view.layoutSubtreeIfNeeded()

    let geometry = view.textView.geometry
    let gap = geometry.top(ofRow: 6) - rowBelowBefore
    #expect(gap > Self.cardHeight)
    let card = try #require(
      view.textView.subviews.first { $0.frame.height == Self.cardHeight }
    )
    #expect(card.frame.minY > geometry.gapTop(afterRow: 5))
    #expect(card.frame.maxY < geometry.top(ofRow: 6))
    #expect(view.textView.misplacedRows == [])
  }

  @Test func takingTheCardAwayClosesItsGap() {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<40).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let before = view.textView.geometry.top(ofRow: 6)
    view.showReviewCards([Self.placement(after: 5)], content: Self.card)

    view.showReviewCards([], content: Self.card)

    #expect(view.textView.geometry.top(ofRow: 6) == before)
    #expect(!view.textView.subviews.contains { $0.frame.height == Self.cardHeight })
  }

  @Test func aSplitOpensACardsGapInBothColumnsSoTheSameOffsetIsTheSameRow() {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let lines = (0..<40).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "line \(index)")
    }
    view.show(SplitDiff(lines, marksStaging: false, committedDigest: 0), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()

    view.onDisk.showReviewCards([Self.placement(after: 5)], content: Self.card)

    #expect(
      view.committed.textView.geometry.top(ofRow: 6) == view.onDisk.textView.geometry.top(ofRow: 6)
    )
    let gaps = view.committed.textView.geometry.rowGaps
    #expect(gaps.heightAbove(row: 6) - gaps.heightAbove(row: 5) > Self.cardHeight)
  }

  @Test func aCardChangingWhileTheTopIsInsideAnotherCardsGapMovesNothingInView() {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<120).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let above = Self.placement(after: 5)
    view.showReviewCards([above], content: Self.card)
    view.layoutSubtreeIfNeeded()
    view.scroll(to: NSPoint(x: 0, y: view.textView.geometry.gapTop(afterRow: 5) + 20))
    let before = view.scrollOrigin.y

    view.showReviewCards([above, Self.placement(after: 90)], content: Self.card)
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollOrigin.y == before)
  }

  @Test func aCardOpeningAboveASplitScrolledFarDownMovesNeitherColumn() {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let lines = (0..<300).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "line \(index)")
    }
    view.show(SplitDiff(lines, marksStaging: false, committedDigest: 0), theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    let geometry = view.onDisk.textView.geometry
    view.onDisk.scroll(to: NSPoint(x: 0, y: geometry.scrollOffset(puttingAtTop: 200)))

    view.onDisk.showReviewCards([Self.placement(after: 5)], content: Self.card)
    view.layoutSubtreeIfNeeded()

    #expect(view.onDisk.topRow == 200)
    #expect(view.committed.topRow == 200)
  }

  @Test func aRevealAskedForBeforeTheViewHasASizeWinsOverTheSavedScroll() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.restore(FileTabScroll(line: 1, isCommittedLine: false, rowsFromLine: 0, x: 0))
    view.show(
      DiffDocumentFixture.contextLines((0..<200).map { "line \($0)" }),
      theme: Theme.builtins[0],
    )
    let placement = Self.placement(after: 150)
    guard case .comment(let comment, _) = placement.card else { throw CancellationError() }
    view.showReviewCards([placement], content: Self.card)

    view.revealReviewCard(.comment(comment.id))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    #expect(view.topRow > 140)
    #expect(view.topRow < 150)
  }

  @Test func aCardClosingUnderACutTopKeepsTheRowsBelowItInView() {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<120).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    view.showReviewCards([Self.placement(after: 40)], content: Self.card)
    view.layoutSubtreeIfNeeded()
    view.scroll(to: NSPoint(x: 0, y: view.textView.geometry.gapTop(afterRow: 40) + 50))

    view.showReviewCards([], content: Self.card)
    view.layoutSubtreeIfNeeded()

    #expect(view.topRow == 41)
  }

  @Test func aSplitRevealBeforeASizeWinsOverTheOtherColumnsSavedScroll() throws {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.restore(FileTabScroll(line: 1, isCommittedLine: false, rowsFromLine: 0, x: 0))
    let lines = (0..<300).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "line \(index)")
    }
    view.show(SplitDiff(lines, marksStaging: false, committedDigest: 0), theme: Theme.builtins[0])
    let placement = Self.placement(after: 250)
    guard case .comment(let comment, _) = placement.card else { throw CancellationError() }
    view.committed.showReviewCards([placement], content: Self.card)

    view.revealReviewCard(.comment(comment.id))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    #expect(view.committed.topRow > 240)
    #expect(view.onDisk.topRow > 240)
  }

  @Test func revealingACommentTallerThanTheClipBringsItsCardIntoView() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<300).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let tall = Self.placement(after: 160)
    guard case .comment(let comment, _) = tall.card else { throw CancellationError() }
    view.showReviewCards(
      [ReviewCardPlacement(card: tall.card, rows: 100...160)],
      content: Self.card,
    )
    view.layoutSubtreeIfNeeded()

    view.revealReviewCard(.comment(comment.id))

    let cardBottom = view.textView.geometry.top(ofRow: 161)
    #expect(cardBottom <= view.scrollOrigin.y + view.clipHeight)
  }

  @Test func cardsWaitForAWidthBeforeOpeningAnyGap() {
    let layer = ReviewCardLayer()
    let textView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))

    let gaps = layer.show(
      [Self.placement(after: 5)],
      content: Self.card,
      in: textView,
      clipWidth: 0,
    )

    #expect(gaps.isEmpty)
    #expect(layer.remeasure(atClipWidth: 400)?[5] ?? 0 > Self.cardHeight)
  }

  @Test func aRevealForACardNotPlacedLeavesTheSavedScrollToBeRestored() {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.restore(FileTabScroll(line: 0, isCommittedLine: false, rowsFromLine: 120, x: 0))
    view.show(
      DiffDocumentFixture.contextLines((0..<300).map { "line \($0)" }),
      theme: Theme.builtins[0],
    )

    view.revealReviewCard(.comment(UUID()))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    #expect(view.scrollOrigin.y == view.textView.geometry.top(ofRow: 120))
  }

  @Test func aSplitRevealBeforeASizeCountsTheCardsOwnGap() throws {
    let view = SplitDiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    let lines = (0..<300).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: index + 1, text: "line \(index)")
    }
    view.show(SplitDiff(lines, marksStaging: false, committedDigest: 0), theme: Theme.builtins[0])
    let tall = Self.placement(after: 160)
    guard case .comment(let comment, _) = tall.card else { throw CancellationError() }
    view.placeReviewCards {
      view.onDisk.showReviewCards(
        [ReviewCardPlacement(card: tall.card, rows: 100...160)],
        content: Self.card,
      )
    }

    view.revealReviewCard(.comment(comment.id))
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.layoutSubtreeIfNeeded()

    let geometry = view.onDisk.textView.geometry
    #expect(geometry.top(ofRow: 161) <= view.onDisk.scrollOrigin.y + view.onDisk.clipHeight)
  }

  @Test func aStepPastATallCardStillBringsTheChangeIntoView() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    let text = DiffDocumentFixture.twoChanges
    view.show(text, theme: Theme.builtins[0])
    view.layoutSubtreeIfNeeded()
    let changeRow = try #require(text.lines.firstIndex { $0.kind == .added })
    view.showReviewCards([Self.placement(after: changeRow - 2)]) { _ in
      AnyView(Color.clear.frame(height: 300))
    }
    view.layoutSubtreeIfNeeded()

    view.step(toChange: .next)

    let top = view.textView.geometry.top(ofRow: changeRow)
    #expect(top >= view.scrollOrigin.y)
    #expect(top < view.scrollOrigin.y + view.clipHeight)
  }

  @Test func revealingTheFirstOfStackedCardsKeepsItsTopInView() throws {
    let view = DiffDocumentView(geometry: DiffRowGeometry(fontFamily: nil, fontSize: 12))
    view.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
    let window = OffscreenWindow.holding(view, deferred: false)
    defer { withExtendedLifetime(window) {} }
    view.show(
      DiffDocumentFixture.contextLines((0..<200).map { "line \($0)" }),
      theme: Theme.builtins[0],
    )
    view.layoutSubtreeIfNeeded()
    let stacked = (0..<3).map { _ in Self.placement(after: 50) }
    guard case .comment(let first, _) = stacked[0].card else { throw CancellationError() }
    view.showReviewCards(stacked) { _ in AnyView(Color.clear.frame(height: 120)) }
    view.layoutSubtreeIfNeeded()

    view.revealReviewCard(.comment(first.id))

    #expect(view.textView.geometry.gapTop(afterRow: 50) >= view.scrollOrigin.y)
  }

  @Test func aComposerOpenedOnALineInViewScrollsNothing() {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<200).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    view.scroll(to: NSPoint(x: 0, y: view.textView.geometry.scrollOffset(puttingAtTop: 20)))
    let composer = Self.composerPlacement(after: 24)
    view.showReviewCards([composer], content: Self.card)
    view.layoutSubtreeIfNeeded()
    let before = view.scrollOrigin.y

    view.revealReviewCard(composer.id)

    #expect(view.scrollOrigin.y == before)
  }

  @Test func aComposerOpenedOnTheLastLineInViewScrollsJustEnoughToShowIt() {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<200).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let lastInView = Int(view.textView.geometry.topRow(atScrollOffset: view.clipHeight)) - 1
    let composer = Self.composerPlacement(after: lastInView)
    view.showReviewCards([composer], content: Self.card)
    view.layoutSubtreeIfNeeded()

    view.revealReviewCard(composer.id)

    let cardEnd = view.textView.geometry.top(ofRow: lastInView + 1)
    #expect(abs(view.scrollOrigin.y + view.clipHeight - cardEnd) < 0.5)
  }

  @Test func editingALongCommentWhoseCardIsInViewScrollsNothing() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<300).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let long = ReviewCardPlacement(card: Self.composerPlacement(after: 150).card, rows: 10...150)
    view.showReviewCards([long], content: Self.card)
    view.layoutSubtreeIfNeeded()
    let span = try #require(view.column.reviewCards.span(of: long.id))
    try #require(span.upperBound - span.lowerBound + 20 < view.clipHeight)
    view.scroll(to: NSPoint(x: 0, y: span.lowerBound - 20))
    let before = view.scrollOrigin.y

    view.revealReviewCard(long.id)

    #expect(view.scrollOrigin.y == before)
  }

  @Test func revealingACommentCardTallerThanTheClipShowsItsTop() throws {
    let (view, window) = DiffDocumentFixture.shown(contextLines: (0..<300).map { "line \($0)" })
    defer { withExtendedLifetime(window) {} }
    let tall = Self.placement(after: 100)
    guard case .comment(let comment, _) = tall.card else { throw CancellationError() }
    view.showReviewCards([tall]) { _ in AnyView(Color.clear.frame(height: 500)) }
    view.layoutSubtreeIfNeeded()

    view.revealReviewCard(.comment(comment.id))

    #expect(view.textView.geometry.gapTop(afterRow: 100) >= view.scrollOrigin.y)
  }
}
