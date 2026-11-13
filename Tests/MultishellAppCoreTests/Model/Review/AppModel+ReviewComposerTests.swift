import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelReviewComposerTests {
  /// README.md in the main worktree rewritten to `text`, its tab's rows read.
  private static func tabShowing(
    _ text: String,
    in harness: GitHarness,
  ) async throws -> (FileTab, Worktree) {
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    try text.write(to: main.path.appending(path: "README.md"), atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil {
      if case .text(let rows) = harness.model.fileTabReadings[tab.id]?.content {
        rows.lines.contains { $0.text == "two" }
      } else {
        false
      }
    }
    return (tab, main)
  }

  private static func rows(of tab: FileTab, in harness: GitHarness) -> [DiffLine] {
    if case .text(let rows) = harness.model.fileTabReadings[tab.id]?.content {
      rows.lines
    } else {
      []
    }
  }

  @Test func addingACommentQuotesTheLinesItIsOnAsTheTabReadThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\nthree\n", in: harness)
    let selection = try #require(
      ReviewLineSelection(from: 1, to: 2, in: Self.rows(of: tab, in: harness), side: .onDisk)
    )

    harness.model.openReviewComposer(on: selection, in: tab.id)
    harness.model.noteReviewDraft("  Merge these.  ", in: tab.id)
    let added = harness.model.commitReviewComposer(in: tab.id)

    #expect(added)
    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    #expect(comment.lines == 2...3)
    #expect(comment.quote == ["two", "three"])
    #expect(comment.text == "Merge these.")
    #expect(harness.model.reviewComposers[tab.id] == nil)
    #expect(harness.model.pendingReviewCommentCount(of: tab) == 1)
  }

  @Test func anEmptyDraftLeavesTheComposerOpenAndAddsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let selection = try #require(
      ReviewLineSelection(from: 1, to: 1, in: Self.rows(of: tab, in: harness))
    )

    harness.model.openReviewComposer(on: selection, in: tab.id)
    harness.model.noteReviewDraft(" \n", in: tab.id)

    #expect(!harness.model.commitReviewComposer(in: tab.id))
    #expect(harness.model.reviewComposers[tab.id] != nil)
    #expect(harness.model.reviewComments(in: main.id).isEmpty)
  }

  @Test func editTurnsACardBackIntoTheComposerHoldingItsTextAndSaveKeepsItsLines() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    let selection = try #require(ReviewLineSelection(from: 1, to: 1, in: rows))
    harness.model.openReviewComposer(on: selection, in: tab.id)
    harness.model.noteReviewDraft("First.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)
    let comment = try #require(harness.model.reviewComments(in: main.id).first)

    harness.model.startEditingReviewComment(comment.id, in: tab.id)
    #expect(harness.model.reviewDraft(in: tab.id) == "First.")
    let composer = try #require(harness.model.reviewComposers[tab.id])
    #expect(
      harness.model.reviewCardPlacements(of: tab, in: rows).map(\.id) == [.composer(composer.id)]
    )
    harness.model.noteReviewDraft("Second.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)

    let edited = try #require(harness.model.reviewComments(in: main.id).first)
    #expect(edited.id == comment.id)
    #expect(edited.text == "Second.")
    #expect(edited.lines == comment.lines)
  }

  @Test func aRemovedLinesCommentShowsOnlyUnderTheScopeItWasWrittenIn() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("two\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    let onDisk = ReviewComment(
      path: tab.path,
      side: .onDisk,
      scope: .branch,
      lines: 1...1,
      quote: ["two"],
      text: "On disk.",
    )
    let removed = ReviewComment(
      path: tab.path,
      side: .committed,
      scope: .branch,
      lines: 1...1,
      quote: ["hello"],
      text: "Removed.",
    )
    harness.model.addReviewComment(onDisk, in: main.id)
    harness.model.addReviewComment(removed, in: main.id)

    let shown = harness.model.reviewCardPlacements(of: tab, in: rows).map(\.id)

    #expect(shown == [.comment(onDisk.id)])
  }

  @Test func aCommentQuotesItsLinesAsTheyReadWhenTheComposerOpened() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let selection = try #require(
      ReviewLineSelection(from: 1, to: 1, in: Self.rows(of: tab, in: harness))
    )
    harness.model.openReviewComposer(on: selection, in: tab.id)
    try "hello\nadded\ntwo\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { Self.rows(of: tab, in: harness).contains { $0.text == "added" } }

    harness.model.noteReviewDraft("Rename it.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)

    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    #expect(comment.quote == ["two"])
  }

  @Test func savingAnEditOfACommentSentMeanwhileAddsTheTextAsANewPendingComment() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let selection = try #require(
      ReviewLineSelection(from: 1, to: 1, in: Self.rows(of: tab, in: harness))
    )
    harness.model.openReviewComposer(on: selection, in: tab.id)
    harness.model.noteReviewDraft("First.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)
    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    harness.model.startEditingReviewComment(comment.id, in: tab.id)
    harness.model.markReviewCommentsSent([comment.id], in: main.id, to: "Codex", at: Date())

    harness.model.noteReviewDraft("Second.", in: tab.id)
    #expect(harness.model.commitReviewComposer(in: tab.id))

    let comments = harness.model.reviewComments(in: main.id)
    #expect(comments.map(\.text) == ["First.", "Second."])
    #expect(comments.last?.isPending == true)
    #expect(comments.last?.quote == comment.quote)
  }

  @Test func savingAnEditOfACommentRemovedMeanwhileAddsTheTextBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let selection = try #require(
      ReviewLineSelection(from: 1, to: 1, in: Self.rows(of: tab, in: harness))
    )
    harness.model.openReviewComposer(on: selection, in: tab.id)
    harness.model.noteReviewDraft("First.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)
    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    harness.model.startEditingReviewComment(comment.id, in: tab.id)
    harness.model.removeReviewComments([comment.id], in: main.id)

    harness.model.noteReviewDraft("Second.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)

    let comments = harness.model.reviewComments(in: main.id)
    #expect(comments.map(\.text) == ["Second."])
    #expect(comments.first?.lines == comment.lines)
  }

  @Test func eachComposerOpenedIsADifferentCardSoItsFieldStartsFromItsOwnDraft() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    let selection = try #require(ReviewLineSelection(from: 1, to: 1, in: rows))
    harness.model.openReviewComposer(on: selection, in: tab.id)
    let first = harness.model.reviewCardPlacements(of: tab, in: rows).map(\.id)

    harness.model.openReviewComposer(on: selection, in: tab.id)
    let second = harness.model.reviewCardPlacements(of: tab, in: rows).map(\.id)

    #expect(first.count == 1)
    #expect(first != second)
  }

  @Test func anotherLineOrEditLeavesAComposerHoldingTextAsItIs() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 0, to: 0, in: rows)),
      in: tab.id,
    )
    harness.model.noteReviewDraft("First.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)
    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    harness.model.noteReviewDraft("Typed.", in: tab.id)
    let open = harness.model.reviewComposers[tab.id]

    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 0, to: 0, in: rows)),
      in: tab.id,
    )
    harness.model.startEditingReviewComment(comment.id, in: tab.id)

    #expect(harness.model.reviewComposers[tab.id] == open)
    #expect(harness.model.reviewDraft(in: tab.id) == "Typed.")
  }

  @Test func closingTheComposerHandsTheKeyboardBackToTheTab() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    _ = harness.model.takeFileTabFocusRequest(tab.id)

    harness.model.cancelReviewComposer(in: tab.id)

    #expect(harness.model.takeFileTabFocusRequest(tab.id))
  }

  @Test func theComposerFollowsItsLinesWhenTheTabReReads() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    let opened = try #require(harness.model.reviewComposers[tab.id])

    try "hello\nadded\ntwo\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { Self.rows(of: tab, in: harness).contains { $0.text == "added" } }

    let composer = try #require(harness.model.reviewComposers[tab.id])
    #expect(composer.id == opened.id)
    #expect(composer.lines == 3...3)
  }

  @Test func aComposerOnRemovedLinesHidesUnderTheOtherScopeAsItsCommentWould() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("two\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.reviewComposers[tab.id] = ReviewComposer(
      side: .committed,
      lines: 1...1,
      quote: ["hello"],
      scope: .branch,
      editing: nil,
    )

    #expect(harness.model.reviewCardPlacements(of: tab, in: rows).isEmpty)
  }

  @Test func aComposerHiddenByTheScopeDoesNotHoldOffANewOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.reviewComposers[tab.id] = ReviewComposer(
      side: .committed,
      lines: 1...1,
      quote: ["old"],
      scope: .branch,
      editing: nil,
    )
    harness.model.noteReviewDraft("Typed under Branch.", in: tab.id)

    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )

    #expect(harness.model.reviewComposers[tab.id]?.side == .onDisk)
  }

  @Test func onlyANewlyOpenedComposerTakesTheKeyboard() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    #expect(harness.model.reviewComposerAsksForKeyboard(in: tab.id))

    harness.model.noteReviewComposerTookKeyboard(in: tab.id)

    #expect(!harness.model.reviewComposerAsksForKeyboard(in: tab.id))
  }

  @Test func anEditLeftUnchangedGivesWayToAnotherEdit() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    for (row, text) in [(0, "First."), (1, "Second.")] {
      harness.model.openReviewComposer(
        on: try #require(ReviewLineSelection(from: row, to: row, in: rows)),
        in: tab.id,
      )
      harness.model.noteReviewDraft(text, in: tab.id)
      harness.model.commitReviewComposer(in: tab.id)
    }
    let comments = harness.model.reviewComments(in: main.id)
    harness.model.startEditingReviewComment(comments[0].id, in: tab.id)

    harness.model.startEditingReviewComment(comments[1].id, in: tab.id)

    #expect(harness.model.reviewComposers[tab.id]?.editing == comments[1].id)
  }

  @Test func aCommentAddedAfterItsLinesChangedUnderTheComposerIsMarkedSo() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    try "hello\nTWO\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { Self.rows(of: tab, in: harness).contains { $0.text == "TWO" } }

    harness.model.noteReviewDraft("Rename it.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)

    let comment = try #require(harness.model.reviewComments(in: main.id).first)
    #expect(comment.hasChangedLines)
  }

  @Test func aComposerOpeningAsksForItsCardToBeScrolledIntoView() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)

    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )

    let composer = try #require(harness.model.reviewComposers[tab.id])
    #expect(harness.model.reviewCardRevealRequests[tab.id] == .composer(composer.id))
  }

  @Test func aComposerWhoseSideHasNoLinesLeftGivesWayToANewOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("hello\ntwo\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 1, to: 1, in: rows)),
      in: tab.id,
    )
    harness.model.noteReviewDraft("Typed.", in: tab.id)
    try "".write(to: main.path.appending(path: "README.md"), atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { Self.rows(of: tab, in: harness).allSatisfy { $0.kind == .removed } }
    let removedRows = Self.rows(of: tab, in: harness)

    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 0, to: 0, in: removedRows)),
      in: tab.id,
    )

    #expect(harness.model.reviewComposers[tab.id]?.side == .committed)
  }

  @Test func aComposerOnRemovedLinesOfADeletedFileGivesWayToANewOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try await Self.tabShowing("two\n", in: harness)
    let rows = Self.rows(of: tab, in: harness)
    let removedRow = try #require(rows.firstIndex { $0.kind == .removed })
    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: removedRow, to: removedRow, in: rows)),
      in: tab.id,
    )
    harness.model.noteReviewDraft("Typed.", in: tab.id)
    try FileManager.default.removeItem(at: main.path.appending(path: "README.md"))
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.fileTabReadings[tab.id]?.isFileGone == true }
    let keptRows = Self.rows(of: tab, in: harness)

    harness.model.openReviewComposer(
      on: try #require(ReviewLineSelection(from: 0, to: 0, in: keptRows)),
      in: tab.id,
    )

    #expect(harness.model.reviewComposers[tab.id]?.side == .onDisk)
  }
}
