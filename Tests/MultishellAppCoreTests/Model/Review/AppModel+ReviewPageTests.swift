import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelReviewPageTests {
  private static func comment(_ path: String = "Sources/App.swift") -> ReviewComment {
    ReviewComment(
      path: path,
      side: .onDisk,
      scope: .modified,
      lines: 3...3,
      quote: ["let a = 1"],
      text: "Guard it.",
    )
  }

  @Test func reviewsGlyphCarriesADotWhileACommentWaitsAndAnotherPageIsShown() {
    let (harness, _) = Harness.withOnePane()
    harness.model.setShowsFilesPanel(true)
    harness.model.setFilesPanelMode(.changes)
    #expect(!harness.model.showsReviewDot)

    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    #expect(harness.model.showsReviewDot)

    harness.model.setFilesPanelMode(.review)
    #expect(!harness.model.showsReviewDot)
  }

  @Test func clickingACommentShowsItsFilesTabAndAsksTheTabToRevealItsCard() async throws {
    let (harness, _) = Harness.withOnePane()
    let comment = Self.comment()
    harness.model.addReviewComment(comment, in: harness.main.id)
    let tab = try #require(harness.store.openFileTab(path: comment.path, in: harness.main.id))
    harness.model.newShellTab()

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.workspaceTabInView?.id == tab.id)
    #expect(harness.model.selectedReviewComments[harness.main.id] == comment.id)
    #expect(harness.model.reviewCardRevealRequests[tab.id] == .comment(comment.id))
  }

  @Test func afterASendTheFooterSaysWhereItWent() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.openTab(in: harness.main.id, title: "Claude", agentID: AgentCatalogue.claudeID)
    harness.model.reconcileSessions(takingFocus: true)
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)

    harness.model.sendReviewToPickedAgent(of: harness.main)

    guard case .sent(let receipt) = harness.model.reviewFooter(of: harness.main) else {
      Issue.record("the footer says what was sent")
      return
    }
    #expect(receipt.summary == "1 comment sent to Claude Code")
  }

  @Test func aRemovedLinesCommentHasNoScopeNoteWhereBranchFallsBackToModified() throws {
    let (harness, _) = Harness.withOnePane()
    harness.model.setChangeScope(.branch)
    let removed = ReviewComment(
      path: "Sources/App.swift",
      side: .committed,
      scope: .modified,
      lines: 3...3,
      quote: ["let a = 0"],
      text: "Why remove it?",
    )
    harness.model.addReviewComment(removed, in: harness.main.id)

    let row = try #require(harness.model.reviewPage(of: harness.main.id).groups.first?.rows.first)

    #expect(row.scopeNote == nil)
  }

  @Test func clearingTheSentCommentsClearsWhatTheFooterSaysWasSent() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.openTab(in: harness.main.id, title: "Claude", agentID: AgentCatalogue.claudeID)
    harness.model.reconcileSessions(takingFocus: true)
    harness.model.addReviewComment(Self.comment(), in: harness.main.id)
    harness.model.sendReviewToPickedAgent(of: harness.main)

    harness.model.clearSentReviewComments(in: harness.main.id)

    if case .sent = harness.model.reviewFooter(of: harness.main) {
      Issue.record("the footer still says what was sent")
    }
  }
}
