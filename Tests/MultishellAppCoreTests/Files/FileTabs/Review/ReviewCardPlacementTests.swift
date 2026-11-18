import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewCardPlacementTests {
  /// context 1, removed old 2, added new 2 and 3, context 4.
  private static let lines = [
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "b"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "B"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "C"),
    DiffLine(kind: .context, oldNumber: 3, newNumber: 4, text: "d"),
  ]

  private static func comment(_ lines: ClosedRange<Int>, side: DiffSide = .onDisk) -> ReviewComment
  {
    ReviewComment(
      path: "a.swift",
      side: side,
      scope: .modified,
      lines: lines,
      quote: ["x"],
      text: "Fix.",
    )
  }

  @Test func aCardSitsUnderTheRowOfItsLastLineOnItsSide() {
    let added = Self.comment(2...3)
    let removed = Self.comment(2...2, side: .committed)

    let placements = ReviewCardPlacement.placements(
      of: [added, removed],
      selected: nil,
      composer: nil,
      in: Self.lines,
    )

    #expect(placements.map(\.id) == [.comment(removed.id), .comment(added.id)])
    #expect(placements.map(\.rows) == [1...1, 2...3])
  }

  @Test func theComposerGoesUnderTheCommentsSharingItsLastRow() {
    let comment = Self.comment(4...4)
    let composer = ReviewComposer(
      path: "a.txt",
      side: .onDisk,
      lines: 1...4,
      quote: ["a", "b", "c", "d"],
      scope: .modified,
      editing: nil,
    )

    let placements = ReviewCardPlacement.placements(
      of: [comment],
      selected: nil,
      composer: composer,
      in: Self.lines,
    )

    #expect(placements.map(\.id) == [.comment(comment.id), .composer(composer.id)])
  }

  @Test func theSelectedCommentsCardIsMarked() {
    let comment = Self.comment(1...1)

    let placements = ReviewCardPlacement.placements(
      of: [comment],
      selected: comment.id,
      composer: nil,
      in: Self.lines,
    )

    #expect(placements.first?.card == .comment(comment, isSelected: true))
  }

  @Test func aCommentOnLinesPastTheFilesEndSitsUnderItsLastLine() {
    let past = Self.comment(9...12)

    let placements = ReviewCardPlacement.placements(
      of: [past],
      selected: nil,
      composer: nil,
      in: Self.lines,
    )

    #expect(placements.map(\.rows) == [4...4])
  }

  @Test func aComposerEditingACommentStandsForItsCard() {
    let comment = Self.comment(2...2)
    let composer = ReviewComposer(
      path: "a.txt",
      side: .onDisk,
      lines: 2...2,
      quote: ["B"],
      scope: .modified,
      editing: comment.id,
    )

    let placement = ReviewCardPlacement(card: .composer(composer), rows: 2...2)

    #expect(placement.stands(for: .comment(comment.id)))
  }
}
