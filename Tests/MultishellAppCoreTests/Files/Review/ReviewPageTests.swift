import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewPageTests {
  private static func comment(
    _ path: String,
    _ lines: ClosedRange<Int>,
    side: DiffSide = .onDisk,
    scope: ChangeScope = .modified,
  ) -> ReviewComment {
    ReviewComment(path: path, side: side, scope: scope, lines: lines, quote: ["x"], text: "Fix.")
  }

  @Test func commentsAreGroupedByFileInPathOrderAndByLineWithin() {
    let page = ReviewPage(
      comments: [
        Self.comment("b/Two.swift", 9...9),
        Self.comment("a/One.swift", 40...41),
        Self.comment("a/One.swift", 3...3),
      ],
      shownScope: .modified,
      selected: nil,
    )

    #expect(page.groups.map(\.fileName) == ["One.swift", "Two.swift"])
    #expect(page.groups[0].rows.map(\.lineLabel) == ["Line 3", "Lines 40–41"])
  }

  @Test func theHeadingAndAFilesCountSayHowManyAreLeftToSend() {
    var sent = Self.comment("a.swift", 2...2)
    sent.markSent(to: "Codex", at: Date())
    let page = ReviewPage(
      comments: [Self.comment("a.swift", 1...1), sent, Self.comment("b.swift", 1...1)],
      shownScope: .modified,
      selected: nil,
    )

    #expect(page.pendingText == "2 to send")
    #expect(page.groups.map(\.countText) == ["1 to send", "1 to send"])
    #expect(page.showsClearSent)
  }

  @Test func aFileWithNothingLeftToSendCountsItsComments() {
    var first = Self.comment("a.swift", 1...1)
    var second = Self.comment("a.swift", 2...2)
    first.markSent(to: "Codex", at: Date())
    second.markSent(to: "Codex", at: Date())

    let page = ReviewPage(comments: [first, second], shownScope: .modified, selected: nil)

    #expect(page.pendingText == nil)
    #expect(page.groups[0].countText == "2 comments")
  }

  @Test func eachRowsChipFollowsItsCommentsState() {
    var sent = Self.comment("a.swift", 1...1)
    sent.markSent(to: "Claude Code", at: Date())
    var outdated = sent
    outdated.noteLinesChanged()
    var changed = Self.comment("a.swift", 3...3)
    changed.noteLinesChanged()

    let chips = [Self.comment("a.swift", 2...2), sent, outdated, changed].map(ReviewChip.init)

    #expect(chips == [.toSend, .sent(agentName: "Claude Code"), .outdated, .linesChanged])
    #expect(chips.map(\.title) == ["To send", "Sent to Claude Code", "Outdated", "Lines changed"])
  }

  @Test func removedLinesWrittenUnderTheOtherScopeSayWhichScopeTheyWereWrittenIn() {
    let page = ReviewPage(
      comments: [
        Self.comment("a.swift", 806...806, side: .committed, scope: .branch),
        Self.comment("a.swift", 900...900, scope: .branch),
      ],
      shownScope: .modified,
      selected: nil,
    )

    #expect(page.groups[0].rows.map(\.lineLabel) == ["Removed line 806", "Line 900"])
    #expect(page.groups[0].rows.map(\.scopeNote) == ["(Branch)", nil])
  }

  @Test func theSelectedCommentsRowIsMarked() {
    let picked = Self.comment("a.swift", 1...1)

    let page = ReviewPage(
      comments: [picked, Self.comment("a.swift", 2...2)],
      shownScope: .modified,
      selected: picked.id,
    )

    #expect(page.groups[0].rows.map(\.isSelected) == [true, false])
  }

  @Test func removedLinesComeBeforeTheAddedOnesOnTheSameLineAsSendOrdersThem() {
    let added = Self.comment("a.swift", 5...5)
    let removed = Self.comment("a.swift", 5...5, side: .committed)

    let page = ReviewPage(comments: [added, removed], shownScope: .modified, selected: nil)

    #expect(page.groups[0].rows.map(\.id) == [removed.id, added.id])
  }

  @Test func aRowOffersDeleteWhilePendingAndDismissOnceSent() {
    var sent = Self.comment("a.swift", 2...2)
    sent.markSent(to: "Codex", at: Date())

    let page = ReviewPage(
      comments: [Self.comment("a.swift", 1...1), sent],
      shownScope: .modified,
      selected: nil,
    )

    #expect(page.groups[0].rows.map(\.chip.removeTitle) == ["Delete", "Dismiss"])
  }
}
