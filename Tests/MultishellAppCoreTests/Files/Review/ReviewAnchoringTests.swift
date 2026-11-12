import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewAnchoringTests {
  private static let path = "Sources/App.swift"

  /// Rows numbered on each side as a file tab's are, from kinds and texts.
  private static func rows(_ lines: [(DiffLine.Kind, String)]) -> [DiffLine] {
    var old = 0
    var new = 0
    return lines.map { kind, text in
      if kind != .added { old += 1 }
      if kind != .removed { new += 1 }
      return DiffLine(
        kind: kind,
        oldNumber: kind == .added ? nil : old,
        newNumber: kind == .removed ? nil : new,
        text: text,
      )
    }
  }

  private static func context(_ texts: [String]) -> [DiffLine] {
    rows(texts.map { (.context, $0) })
  }

  private static func comment(
    on lines: ClosedRange<Int>,
    quoting quote: [String],
    side: DiffSide = .onDisk,
    scope: ChangeScope = .modified,
  ) -> ReviewComment {
    ReviewComment(
      path: path,
      side: side,
      scope: scope,
      lines: lines,
      quote: quote,
      text: "Fix it.",
    )
  }

  private static func reanchored(
    _ comment: ReviewComment,
    to rows: [DiffLine],
    readUnder scope: ChangeScope = .modified,
  ) -> ReviewComment {
    ReviewAnchoring.reanchor([comment], onFile: path, to: rows, readUnder: scope)[0]
  }

  @Test func aCommentWhoseLinesStillReadAsQuotedStaysPut() {
    let comment = Self.comment(on: 2...3, quoting: ["b", "c"])

    let after = Self.reanchored(comment, to: Self.context(["a", "b", "c", "d"]))

    #expect(after == comment)
  }

  @Test func linesAddedAboveMoveTheCommentDownWithItsText() {
    let comment = Self.comment(on: 2...3, quoting: ["b", "c"])

    let after = Self.reanchored(comment, to: Self.context(["new", "new", "a", "b", "c"]))

    #expect(after.lines == 4...5)
    #expect(!after.hasChangedLines)
  }

  @Test func aQuoteFoundTwiceGoesToTheCopyNearestItsOldLines() {
    let comment = Self.comment(on: 5...5, quoting: ["}"])

    let after = Self.reanchored(
      comment,
      to: Self.context(["}", "a", "b", "c", "d", "e", "}", "f", "g", "}"]),
    )

    #expect(after.lines == 7...7)
  }

  @Test func aPendingCommentWhoseLinesChangedStaysMarkedOnItsOldLines() {
    let comment = Self.comment(on: 2...3, quoting: ["b", "c"])

    let after = Self.reanchored(comment, to: Self.context(["a", "B", "c", "d"]))

    #expect(after.isPending)
    #expect(after.hasChangedLines)
    #expect(after.lines == 2...3)
  }

  @Test func aPendingCommentPastTheEndOfAShortenedFileKeepsItsLines() {
    let comment = Self.comment(on: 8...9, quoting: ["h", "i"])

    let after = Self.reanchored(comment, to: Self.context(["a", "b"]))

    #expect(after.lines == 8...9)
    #expect(after.hasChangedLines)
  }

  @Test func changedLinesPutBackClearThePendingCommentsMark() {
    let changed = Self.reanchored(
      Self.comment(on: 2...2, quoting: ["b"]),
      to: Self.context(["a", "B"]),
    )

    let after = Self.reanchored(changed, to: Self.context(["a", "b"]))

    #expect(!after.hasChangedLines)
  }

  @Test func aSentCommentWhoseLinesTheAgentChangedIsOutdated() {
    var comment = Self.comment(on: 2...2, quoting: ["b"])
    let sentAt = Date(timeIntervalSince1970: 100)
    comment.markSent(to: "Codex", at: sentAt)

    let after = Self.reanchored(comment, to: Self.context(["a", "B"]))

    #expect(after.state == .outdated(agentName: "Codex", at: sentAt))
  }

  @Test func aCommentOnRemovedLinesFollowsTheCommittedSide() {
    let comment = Self.comment(on: 2...2, quoting: ["old"], side: .committed)
    let rows = Self.rows([
      (.context, "top"), (.context, "a"), (.removed, "old"), (.added, "new"),
    ])

    let after = Self.reanchored(comment, to: rows)

    #expect(after.lines == 3...3)
    #expect(!after.hasChangedLines)
  }

  @Test func aCommittedSideCommentIsLeftAloneUnderTheOtherScope() {
    let comment = Self.comment(on: 2...2, quoting: ["old"], side: .committed, scope: .branch)

    let after = Self.reanchored(comment, to: Self.context(["a", "b"]), readUnder: .modified)

    #expect(after == comment)
  }

  @Test func anOnDiskCommentFollowsItsLinesUnderEitherScope() {
    let comment = Self.comment(on: 1...1, quoting: ["b"], scope: .branch)

    let after = Self.reanchored(comment, to: Self.context(["a", "b"]), readUnder: .modified)

    #expect(after.lines == 2...2)
  }

  @Test func aCommentOnAnotherFileIsLeftAlone() {
    let other = ReviewComment(
      path: "Other.swift",
      side: .onDisk,
      scope: .modified,
      lines: 1...1,
      quote: ["zzz"],
      text: "Fix it.",
    )

    let after = ReviewAnchoring.reanchor(
      [other],
      onFile: Self.path,
      to: Self.context(["a"]),
      readUnder: .modified,
    )

    #expect(after == [other])
  }

  @Test func anOutdatedCommentWhoseLinesReadAsQuotedAgainIsSentOnceMore() {
    var comment = Self.comment(on: 2...2, quoting: ["b"])
    let sentAt = Date(timeIntervalSince1970: 100)
    comment.markSent(to: "Codex", at: sentAt)
    let outdated = Self.reanchored(comment, to: Self.context(["a", "B"]))

    let after = Self.reanchored(outdated, to: Self.context(["a", "b"]))

    #expect(after.state == .sent(agentName: "Codex", at: sentAt))
    #expect(after.lines == 2...2)
  }

  @Test func aReadThatSawTheFileCutShortLeavesTheNextReadSearchingNearTheOldLines() {
    let comment = Self.comment(on: 5...5, quoting: ["}"])
    let cut = Self.reanchored(comment, to: Self.context(["a"]))

    let after = Self.reanchored(cut, to: Self.context(["a", "}", "b", "c", "}"]))

    #expect(after.lines == 5...5)
  }
}
