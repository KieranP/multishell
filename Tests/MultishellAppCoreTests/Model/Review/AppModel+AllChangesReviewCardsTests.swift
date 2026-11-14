import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelAllChangesReviewCardsTests {
  private static func numbered(_ prefix: String, lines: Int) -> FileTabRows {
    FileTabRows(
      lines: (1...lines).map { line in
        DiffLine(
          kind: line == 1 ? .added : .context,
          oldNumber: line == 1 ? nil : line - 1,
          newNumber: line,
          text: "\(prefix) \(line)",
        )
      },
      marksStaging: true,
    )
  }

  private static func comment(on path: String, line: Int, quote: String) -> ReviewComment {
    ReviewComment(
      path: path,
      side: .onDisk,
      scope: .modified,
      lines: line...line,
      quote: [quote],
      text: "Look.",
    )
  }

  /// `a.txt` and `b.txt` read, each its prefix and number a line, `lines` long.
  private static func tabWithTwoFiles(
    _ harness: Harness,
    lines: Int = 5,
  ) throws -> AllChangesTab {
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.allChangesReadings[tab.id] = .sample(rows: [
      ("a.txt", Self.numbered("a", lines: lines)), ("b.txt", Self.numbered("b", lines: lines)),
    ])
    return tab
  }

  @Test func twoFilesCommentedOnTheSameLineNumberKeepEachTheirOwnCard() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let onA = Self.comment(on: "a.txt", line: 3, quote: "a 3")
    let onB = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(onA, in: harness.main.id)
    harness.model.addReviewComment(onB, in: harness.main.id)
    let document = try #require(harness.model.allChangesDocument(of: tab.id))

    let placements = harness.model.reviewCardPlacements(of: tab, in: document)

    let rowsByComment = Dictionary(
      uniqueKeysWithValues: placements.map { placement in
        (placement.id, document.text.lines[placement.rows.lowerBound].text)
      }
    )
    #expect(rowsByComment == [.comment(onA.id): "a 3", .comment(onB.id): "b 3"])
  }

  @Test func theComposerQuotesAndCommentsOnTheFileItsLinesAreIn() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let document = try #require(harness.model.allChangesDocument(of: tab.id))
    let row = try #require(document.sections[1].documentRow(ofFileRow: 2))
    let picked = try #require(document.lineSelection(from: row, to: row, side: nil))

    harness.model.openReviewComposer(on: picked.selection, ofFile: picked.path, in: tab.id)
    harness.model.noteReviewDraft("Here.", in: tab.id)
    harness.model.commitReviewComposer(in: tab.id)

    let comment = try #require(harness.model.reviewComments(in: harness.main.id).first)
    #expect(comment.path == "b.txt")
    #expect(comment.lines == 3...3)
    #expect(comment.quote == ["b 3"])
  }

  @Test func aDragStartingInOneFileStopsAtItsLastRow() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let document = try #require(harness.model.allChangesDocument(of: tab.id))
    let lastOfA = document.sections[0].rows.upperBound - 1

    let picked = try #require(document.lineSelection(from: lastOfA, to: lastOfA + 3, side: nil))

    #expect(picked.path == "a.txt")
    #expect(picked.selection.lines == 5...5)
  }

  @Test func aCommentOnAnUnchangedLineHoldsTwoLinesEitherSideOutOfItsFold() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness, lines: 30)
    harness.model.addReviewComment(
      Self.comment(on: "a.txt", line: 20, quote: "a 20"),
      in: harness.main.id,
    )

    let document = try #require(harness.model.allChangesDocument(of: tab.id))

    let shown = document.text.lines[document.sections[0].rows].compactMap(\.newNumber)
    #expect(shown == [1, 2, 3, 4, 18, 19, 20, 21, 22])
  }

  @Test func closingTheTabWhileItsComposerHoldsTextAsksFirst() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let document = try #require(harness.model.allChangesDocument(of: tab.id))
    let picked = try #require(document.lineSelection(from: 0, to: 0, side: nil))
    harness.model.openReviewComposer(on: picked.selection, ofFile: picked.path, in: tab.id)
    harness.model.noteReviewDraft("Typed.", in: tab.id)

    harness.model.closeTab(tab.id)

    #expect(harness.model.workspace.allChangesTab(tab.id) != nil, "the draft would go with it")
    let pending = try #require(harness.model.pendingClose)
    harness.model.answerClose(pending, confirmed: true)
    #expect(harness.model.workspace.allChangesTab(tab.id) == nil)
    #expect(harness.model.reviewComposers[tab.id] == nil, "pruned with the tab")
  }

  @Test func aCommentPickedInReviewIsRevealedInTheShownAllChangesTabItsFileExpanded() async throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let comment = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(comment, in: harness.main.id)
    harness.model.toggleAllChangesFileCollapsed("b.txt", in: tab.id)

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.workspace.fileTabs.isEmpty, "no file tab opened")
    #expect(!harness.model.isAllChangesFileCollapsed("b.txt", in: tab.id))
    #expect(harness.model.takeReviewCardReveal(tab.id) == .comment(comment.id))
  }

  @Test func reviewAddQuotesThroughTheAllChangesTabWhereNoFileTabShowsThePath() async throws {
    let harness = Harness()
    _ = try Self.tabWithTwoFiles(harness)

    let reply = await harness.messageSource.ask(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: "b.txt",
          side: .onDisk,
          lines: 2...3,
          text: "Why?",
        )
      )
    )

    #expect(reply?.outputFields["comments"] != nil)
    #expect(harness.model.reviewComments(in: harness.main.id).first?.quote == ["b 2", "b 3"])
  }
}
