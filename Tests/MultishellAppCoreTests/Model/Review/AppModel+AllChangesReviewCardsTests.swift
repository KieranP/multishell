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
    ReviewComment.sample(path: path, lines: line...line, quote: [quote], text: "Look.")
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

    let rowsByComment = Dictionary(
      uniqueKeysWithValues: document.sections.indices.flatMap { index in
        let lines = document.slice(ofSection: index).text.lines
        return harness.model.reviewCardPlacements(of: tab, in: document, section: index)
          .map { placement in (placement.id, lines[placement.rows.lowerBound].text) }
      }
    )
    #expect(rowsByComment == [.comment(onA.id): "a 3", .comment(onB.id): "b 3"])
  }

  @Test func aComposerHoldingLinesOutOfAFoldMovesTheFindMatchesBelowIt() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness, lines: 20)
    harness.model.showFind()
    harness.model.setFindText("b 1", of: tab.id)
    let before = try #require(harness.model.allChangesDocument(of: tab.id))
    let row = try #require(before.sections[0].documentRow(ofFileRow: 3))
    let picked = try #require(before.lineSelection(from: row, to: row, side: nil))

    harness.model.openReviewComposer(on: picked.selection, ofFile: picked.path, in: tab.id)

    let after = try #require(harness.model.allChangesDocument(of: tab.id))
    #expect(after.text.lines.count > before.text.lines.count)
    let match = try #require(harness.model.fileFindMatches(of: tab.id).first)
    #expect(after.text.uncutText(in: match) == "b 1")
  }

  @Test func rowsPickedInAFileSplitShowsWholeAreItsOwnLines() throws {
    let harness = Harness()
    harness.model.setFileTabLayout(.split)
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let added = (1...4).map { (number: Int) in
      DiffLine(kind: .added, oldNumber: nil, newNumber: number, text: "new \(number)")
    }
    harness.model.allChangesReadings[tab.id] = .sample(rows: [
      ("a.txt", FileTabRows(lines: added, marksStaging: true))
    ])

    harness.model.openReviewComposer(fromRow: 1, toRow: 2, ofSection: 0, side: nil, in: tab.id)

    let composer = try #require(harness.model.reviewComposers[tab.id])
    #expect(composer.path == "a.txt")
    #expect(composer.lines == 2...3)
  }

  @Test func aCommentPickedInReviewStopsOnItsLineInItsOwnFile() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let comment = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(comment, in: harness.main.id)
    let document = try #require(harness.model.allChangesDocument(of: tab.id))

    let stop = harness.model.reviewCardRow(.comment(comment.id), of: tab, in: document)

    let row = try #require(stop?.row)
    #expect(stop?.section == 1)
    #expect(document.slice(ofSection: 1).text.lines[row].text == "b 3")
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

  @Test func aDragAcrossAFoldStopsAtTheFold() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness, lines: 30)
    harness.model.addReviewComment(
      Self.comment(on: "a.txt", line: 20, quote: "a 20"),
      in: harness.main.id,
    )
    let document = try #require(harness.model.allChangesDocument(of: tab.id))
    let section = document.sections[0]
    let onLine3 = try #require(section.documentRow(ofFileRow: 2))
    let onLine19 = try #require(section.documentRow(ofFileRow: 18))

    let down = try #require(document.lineSelection(from: onLine3, to: onLine19, side: nil))
    let up = try #require(document.lineSelection(from: onLine19, to: onLine3, side: nil))

    #expect(down.selection.lines == 3...4)
    #expect(up.selection.lines == 18...19)
  }

  @Test func aGutterDragUpAcrossAFoldKeepsTheRowsItStartedOn() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness, lines: 30)
    harness.model.addReviewComment(
      Self.comment(on: "a.txt", line: 20, quote: "a 20"),
      in: harness.main.id,
    )

    harness.model.openReviewComposer(fromRow: 5, toRow: 2, ofSection: 0, side: nil, in: tab.id)

    #expect(harness.model.reviewComposers[tab.id]?.lines == 18...19)
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

  @Test func aCommentOnLinesPastTheFilesEndKeepsItsCardUnderTheLastLine() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness, lines: 30)
    let comment = Self.comment(on: "a.txt", line: 40, quote: "gone")
    harness.model.addReviewComment(comment, in: harness.main.id)

    let document = try #require(harness.model.allChangesDocument(of: tab.id))
    let placement = try #require(
      harness.model.reviewCardPlacements(of: tab, in: document, section: 0).first
    )

    #expect(placement.id == .comment(comment.id))
    #expect(document.slice(ofSection: 0).text.lines[placement.rows.lowerBound].text == "a 30")
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

  @Test func aPlusOnAnotherFileKeepsADraftWhoseFileWaitsToBeReadAgain() throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let read = try #require(harness.model.allChangesReadings[tab.id])
    harness.model.openReviewComposer(fromRow: 2, toRow: 2, ofSection: 0, side: nil, in: tab.id)
    harness.model.noteReviewDraft("Typed.", in: tab.id)
    harness.model.allChangesReadings[tab.id] = .sample([
      ("a.txt", .unread), ("b.txt", read.files[1].content),
    ])

    harness.model.openReviewComposer(fromRow: 2, toRow: 2, ofSection: 1, side: nil, in: tab.id)

    #expect(harness.model.reviewComposers[tab.id]?.path == "a.txt")
    #expect(harness.model.reviewDraft(in: tab.id) == "Typed.")
  }

  @Test func aCommentPickedInReviewIsRevealedInTheShownAllChangesTabItsFileExpanded() async throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let comment = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(comment, in: harness.main.id)
    harness.model.toggleAllChangesFileCollapsed("b.txt", in: tab.id)

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.workspace.fileTabs.isEmpty, "no file tab opened")
    #expect(harness.model.allChangesCollapsedFiles[tab.id]?.contains("b.txt") != true)
    #expect(harness.model.takeReviewCardReveal(tab.id) == .comment(comment.id))
  }

  @Test func aCommentPickedOnAFileTheAllChangesTabDoesNotListOpensInItsFilesTab() async throws {
    let harness = Harness()
    let fileTab = try #require(harness.store.openFileTab(path: "c.txt", in: harness.main.id))
    let tab = try Self.tabWithTwoFiles(harness)
    let comment = Self.comment(on: "c.txt", line: 3, quote: "c 3")
    harness.model.addReviewComment(comment, in: harness.main.id)

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.workspaceTabInView?.id == fileTab.id)
    #expect(harness.model.reviewCardRevealRequests[tab.id] == nil)
  }

  @Test func aCommentPickedOnAFileTheTabShowsNoRowsOfOpensInItsFilesTab() async throws {
    let harness = Harness()
    let fileTab = try #require(harness.store.openFileTab(path: "b.txt", in: harness.main.id))
    let tab = try Self.tabWithTwoFiles(harness)
    let read = try #require(harness.model.allChangesReadings[tab.id])
    harness.model.allChangesReadings[tab.id] = .sample([
      ("a.txt", read.files[0].content), ("b.txt", .pastRowCap),
    ])
    let comment = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(comment, in: harness.main.id)

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.workspaceTabInView?.id == fileTab.id)
  }

  @Test func aCommentPickedOnAFileNotYetReadWaitsForItsReadThenIsRevealed() async throws {
    let harness = Harness()
    let tab = try Self.tabWithTwoFiles(harness)
    let read = try #require(harness.model.allChangesReadings[tab.id])
    harness.model.allChangesReadings[tab.id] = .sample([
      ("a.txt", read.files[0].content), ("b.txt", .unread),
    ])
    let comment = Self.comment(on: "b.txt", line: 3, quote: "b 3")
    harness.model.addReviewComment(comment, in: harness.main.id)

    await harness.model.selectReviewComment(comment.id, in: harness.main.id)

    #expect(harness.model.takeReviewCardReveal(tab.id) == nil)
    #expect(harness.model.takeAllChangesFileReveal(tab.id) == "b.txt")
    harness.model.allChangesReadings[tab.id] = read
    #expect(harness.model.takeReviewCardReveal(tab.id) == .comment(comment.id))
  }

  @Test func reviewAddIsRefusedWhereOnlyTheAllChangesTabShowsThePath() async throws {
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

    #expect(reply == .refused(.noReviewTab(path: "b.txt")))
    #expect(harness.model.reviewComments(in: harness.main.id).isEmpty)
  }
}
