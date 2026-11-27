import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelReviewCommentsTests {
  private static func comment(_ text: String = "Guard it.") -> ReviewComment {
    .sample(text: text)
  }

  @Test func aCommentWithOnlyWhitespaceIsRefused() {
    let harness = Harness()

    let added = harness.model.addReviewComment(Self.comment(" \n "), in: harness.feature.id)

    #expect(!added)
    #expect(harness.model.reviewComments(in: harness.feature.id).isEmpty)
  }

  @Test func editingChangesAPendingCommentsTextButNotASentOnes() {
    let harness = Harness()
    let pending = Self.comment("first")
    let sent = Self.comment("second")
    harness.model.addReviewComment(pending, in: harness.feature.id)
    harness.model.addReviewComment(sent, in: harness.feature.id)
    harness.model.markReviewCommentsSent(
      [sent.id],
      in: harness.feature.id,
      to: "Codex",
      at: Date(),
    )

    harness.model.editReviewComment(pending.id, in: harness.feature.id, text: "edited")
    harness.model.editReviewComment(sent.id, in: harness.feature.id, text: "edited")

    #expect(
      harness.model.reviewComments(in: harness.feature.id).map(\.text) == ["edited", "second"]
    )
  }

  @Test func clearSentKeepsOnlyThePendingComments() {
    let harness = Harness()
    let pending = Self.comment("pending")
    let sent = Self.comment("sent")
    harness.model.addReviewComment(pending, in: harness.feature.id)
    harness.model.addReviewComment(sent, in: harness.feature.id)
    harness.model.markReviewCommentsSent(
      [sent.id],
      in: harness.feature.id,
      to: "Codex",
      at: Date(),
    )

    harness.model.clearSentReviewComments(in: harness.feature.id)

    #expect(harness.model.reviewComments(in: harness.feature.id).map(\.id) == [pending.id])
  }

  @Test func aRemovedWorktreeTakesItsCommentsFileWithIt() throws {
    let harness = Harness()
    harness.model.addReviewComment(Self.comment(), in: harness.feature.id)
    harness.model.saveNow()

    harness.model.forgetWorktrees(
      harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)
    )
    harness.model.writeReviewCommentsNow()

    #expect(harness.model.reviewComments(in: harness.feature.id).isEmpty)
    #expect(harness.reviewFileNames.isEmpty)
  }

  @Test func aRemovedWorktreeTakesEvenAnUnreadableCommentsFileWithIt() throws {
    let harness = Harness()
    let file = ReviewFile(worktreeID: harness.feature.id, in: harness.reviews)
    try file.save([Self.comment()], as: file.issueTicket())
    let name = try #require(harness.reviewFileNames.first)
    let unreadable = #"{"worktree":"\#(harness.feature.id)","comments":[{}]}"#
    try Data(unreadable.utf8).write(to: harness.reviews.appendingPathComponent(name))
    let (after, _, store, _) = harness.relaunched()
    #expect(after.reviewComments(in: harness.feature.id).isEmpty)

    after.forgetWorktrees(store.replaceWorktrees([harness.main], forProject: harness.project.id))
    after.writeReviewCommentsNow()

    #expect(harness.reviewFileNames.isEmpty)
  }

  @Test func clearingSentCommentsWhereThereAreNoneWritesNoFile() {
    let harness = Harness()

    harness.model.clearSentReviewComments(in: harness.feature.id)
    harness.model.removeReviewComments([UUID()], in: harness.feature.id)

    #expect(harness.model.reviewFiles[harness.feature.id] == nil)
  }

  @Test func aFilesPendingCountLeavesOutOtherFilesAndSentComments() {
    let harness = Harness()
    let pending = Self.comment()
    let sent = Self.comment("Sent.")
    let elsewhere = ReviewComment.sample(
      path: "Sources/Other.swift",
      lines: 1...1,
      quote: ["x"],
      text: "Elsewhere.",
    )
    for comment in [pending, sent, elsewhere] {
      harness.model.addReviewComment(comment, in: harness.feature.id)
    }
    harness.model.markReviewCommentsSent(
      [sent.id],
      in: harness.feature.id,
      to: "Codex",
      at: Date(),
    )

    #expect(
      harness.model.pendingReviewCommentCounts(in: harness.feature.id)[pending.path] == 1
    )
  }

  @Test func thePanelsPendingCountsAreByPathOverEveryFile() {
    let harness = Harness()
    let other = ReviewComment.sample(
      path: "Sources/Other.swift",
      lines: 1...1,
      quote: ["x"],
      text: "Elsewhere.",
    )
    harness.model.addReviewComment(Self.comment(), in: harness.feature.id)
    harness.model.addReviewComment(Self.comment("Again."), in: harness.feature.id)
    harness.model.addReviewComment(other, in: harness.feature.id)

    let counts = harness.model.pendingReviewCommentCounts(in: harness.feature.id)

    #expect(counts == ["Sources/App.swift": 2, "Sources/Other.swift": 1])
  }

  @Test func forgettingAWorktreeWithNoReviewStateRedrawsNothing() {
    let harness = Harness()
    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.selectedReviewComments
      _ = harness.model.reviewSendReceipts
    } onChange: {
      wrote.raise()
    }

    harness.model.forgetReviewState(of: [harness.feature.id])

    #expect(!wrote.raised)
  }
}
