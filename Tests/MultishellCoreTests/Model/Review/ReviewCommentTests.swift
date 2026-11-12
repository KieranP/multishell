import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ReviewCommentTests {
  private static let week: TimeInterval = 7 * 24 * 60 * 60
  private static let sentAt = Date(timeIntervalSince1970: 1_000_000)

  private static func comment(_ state: ReviewComment.State) -> ReviewComment {
    var comment = ReviewComment(
      path: "a.swift",
      side: .onDisk,
      scope: .modified,
      lines: 1...1,
      quote: ["x"],
      text: "Fix it.",
    )
    comment.state = state
    return comment
  }

  @Test func aSentCommentOutlivesItsFileOnceTheRetentionHasPassed() {
    let sent = Self.comment(.sent(agentName: "Codex", at: Self.sentAt))

    #expect(!sent.outlivesItsSentFile(at: Self.sentAt + Self.week, retention: Self.week))
    #expect(sent.outlivesItsSentFile(at: Self.sentAt + Self.week + 1, retention: Self.week))
  }

  @Test func anOutdatedCommentAgesFromWhenItWasSent() {
    let outdated = Self.comment(.outdated(agentName: "Codex", at: Self.sentAt))

    #expect(outdated.outlivesItsSentFile(at: Self.sentAt + Self.week + 1, retention: Self.week))
  }

  @Test func aPendingCommentNeverAgesOut() {
    let pending = Self.comment(.pending)

    #expect(!pending.outlivesItsSentFile(at: .distantFuture, retention: Self.week))
  }

  @Test func aCommentSentWithChangedLinesStaysSentWhenItsQuoteIsStillMissing() {
    var comment = Self.comment(.pending)
    comment.noteLinesChanged()
    comment.markSent(to: "Codex", at: Self.sentAt)

    comment.noteLinesChanged()

    #expect(comment.state == .sent(agentName: "Codex", at: Self.sentAt))
  }

  @Test func aMissedQuoteKeepsTheLinesTheNextReadSearchesNear() {
    var comment = Self.comment(.sent(agentName: "Codex", at: Self.sentAt))
    comment.lines = 200...205

    comment.noteLinesChanged()

    #expect(comment.state == .outdated(agentName: "Codex", at: Self.sentAt))
    #expect(comment.lines == 200...205)
  }

  @Test func aCommentSentWithChangedLinesTurnsOutdatedOnceItsQuoteWasFoundAndThenChanged() {
    var comment = Self.comment(.pending)
    comment.noteLinesChanged()
    comment.markSent(to: "Codex", at: Self.sentAt)
    comment.anchor(at: 1...1)

    comment.noteLinesChanged()

    #expect(comment.state == .outdated(agentName: "Codex", at: Self.sentAt))
  }
}
