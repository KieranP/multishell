import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlReviewTests {
  /// The main worktree in view with a Codex tab behind `a.swift`, its rows
  /// read: two lines before, `old 0` replaced by `new 0` and `new 1`, one after.
  private static func harnessWithFileRead() throws -> (Harness, FileTab) {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.store.openTab(in: harness.main.id, title: "Codex", agentID: AgentCatalogue.codexID)
    harness.model.reconcileSessions(takingFocus: false)
    let tab = try #require(harness.store.openFileTab(path: "a.swift", in: harness.main.id))
    harness.model.activateTab(tab.id)
    harness.model.fileTabReadings[tab.id] = FileTabReading(
      content: .text(.replacedBlock(before: 2, removed: 1, added: 2, after: 1)),
      isFileGone: false,
    )
    return (harness, tab)
  }

  private static func order(
    _ lines: ClosedRange<Int>,
    side: DiffSide,
    text: String,
  ) -> ReviewCommentOrder {
    ReviewCommentOrder(worktreeID: nil, path: "a.swift", side: side, lines: lines, text: text)
  }

  private static func comments(in reply: ControlReply?) -> [[String: Any]] {
    reply?.outputFields["comments"] as? [[String: Any]] ?? []
  }

  @Test func addingQuotesTheTabsLinesAndTheListSaysWhereEachCommentIs() async throws {
    let (harness, _) = try Self.harnessWithFileRead()

    let reply = await harness.messageSource.ask(
      .addReviewComment(Self.order(3...4, side: .onDisk, text: "Why?"))
    )

    let comment = try #require(Self.comments(in: reply).first)
    #expect(comment["path"] as? String == "a.swift")
    #expect(comment["firstLine"] as? Int == 3)
    #expect(comment["lastLine"] as? Int == 4)
    #expect(comment["state"] as? String == "pending")
    #expect(harness.model.reviewComments(in: harness.main.id).first?.quote == ["new 0", "new 1"])
  }

  @Test func linesTheTabHasNotReadAreRefused() async throws {
    let (harness, _) = try Self.harnessWithFileRead()

    let reply = await harness.messageSource.ask(
      .addReviewComment(Self.order(4...9, side: .onDisk, text: "Far."))
    )

    #expect(reply == .refused(.noReviewLines(path: "a.swift")))
  }

  @Test func sendingWithNothingPendingOrToAPaneWithNoAgentIsRefused() async throws {
    let (harness, _) = try Self.harnessWithFileRead()
    let worktree = ControlID.worktree(harness.main.id)

    #expect(
      await harness.messageSource.ask(.sendReview(worktree: nil, to: nil))
        == .refused(.nothingToSend(id: worktree))
    )
    _ = await harness.messageSource.ask(
      .addReviewComment(Self.order(3...3, side: .committed, text: "Ok"))
    )
    harness.store.openTab(in: harness.main.id, title: "Shell")
    harness.model.reconcileSessions(takingFocus: false)
    let shell = try #require(
      harness.model.workspace.sessions(in: harness.main.id).first { $0.agentID == nil }
    )
    #expect(
      await harness.messageSource.ask(.sendReview(worktree: nil, to: shell.id))
        == .refused(.noReviewRecipient(id: worktree))
    )
  }

  @Test func sendingToAnAgentPaneMarksTheCommentsSentToIt() async throws {
    let (harness, _) = try Self.harnessWithFileRead()
    _ = await harness.messageSource.ask(
      .addReviewComment(Self.order(1...1, side: .onDisk, text: "One"))
    )

    let reply = await harness.messageSource.ask(.sendReview(worktree: nil, to: nil))

    let comment = try #require(Self.comments(in: reply).first)
    #expect(comment["state"] as? String == "sent")
    #expect(comment["agent"] as? String == "Codex")
  }

  @Test func sendingLeavesTheShownTabAndTheKeyboardAlone() async throws {
    let (harness, tab) = try Self.harnessWithFileRead()
    _ = await harness.messageSource.ask(
      .addReviewComment(Self.order(1...1, side: .onDisk, text: "One"))
    )
    let focusedBefore = harness.engine.focused

    _ = await harness.messageSource.ask(.sendReview(worktree: nil, to: nil))

    #expect(harness.model.reviewComments(in: harness.main.id).first?.isPending == false)
    #expect(harness.model.workspaceTabInView?.id == tab.id)
    #expect(harness.engine.focused == focusedBefore)
  }

  @Test func clearSentLeavesThePendingAndClearRemovesEverything() async throws {
    let (harness, _) = try Self.harnessWithFileRead()
    _ = await harness.messageSource.ask(
      .addReviewComment(Self.order(1...1, side: .onDisk, text: "One"))
    )
    _ = await harness.messageSource.ask(.sendReview(worktree: nil, to: nil))
    let pending = ReviewComment(
      path: "a.swift",
      side: .onDisk,
      scope: .modified,
      lines: 2...2,
      quote: ["before 1"],
      text: "Two",
    )
    harness.model.addReviewComment(pending, in: harness.main.id)

    let cleared = await harness.messageSource.ask(
      .clearReviewComments(worktree: nil, sentOnly: true)
    )
    #expect(Self.comments(in: cleared).compactMap { $0["text"] as? String } == ["Two"])
    let emptied = await harness.messageSource.ask(
      .clearReviewComments(worktree: nil, sentOnly: false)
    )
    #expect(Self.comments(in: emptied).isEmpty)
  }

  @Test func removedLinesThatTheFileStillHasAreRefusedForHoldingNoRemovedLine() async throws {
    let (harness, _) = try Self.harnessWithFileRead()

    let reply = await harness.messageSource.ask(
      .addReviewComment(Self.order(1...1, side: .committed, text: "Kept."))
    )

    #expect(reply == .refused(.noRemovedLines(path: "a.swift")))
  }

  @Test func anAddedCommentsTextIsTrimmedAsTheComposerTrimsIt() async throws {
    let (harness, _) = try Self.harnessWithFileRead()

    _ = await harness.messageSource.ask(
      .addReviewComment(Self.order(3...3, side: .onDisk, text: "\n  Why?\n\n"))
    )

    #expect(harness.model.reviewComments(in: harness.main.id).first?.text == "Why?")
  }

  @Test func aCommentOnALinkGoesOnTheFileItLinksTo() async throws {
    let (harness, _) = try Self.harnessWithFileRead()
    let worktree = harness.main.path
    try "x\n".write(to: worktree.appending(path: "a.swift"), atomically: true, encoding: .utf8)
    try FileManager.default.createSymbolicLink(
      atPath: worktree.appending(path: "link.swift").path,
      withDestinationPath: "a.swift",
    )

    _ = await harness.messageSource.ask(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: "link.swift",
          side: .onDisk,
          lines: 3...3,
          text: "Why?",
        )
      )
    )

    #expect(harness.model.reviewComments(in: harness.main.id).first?.path == "a.swift")
  }

  @Test func addingRightAfterOpeningTheFileWaitsForItsFirstRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    _ = await harness.model.answer(
      .openFileTab(worktree: ControlID.worktree(main.id), path: "README.md")
    )

    _ = await harness.model.answer(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: "README.md",
          side: .onDisk,
          lines: 1...1,
          text: "Why?",
        )
      )
    )

    #expect(harness.model.reviewComments(in: main.id).count == 1)
  }

  @Test func aTabNotShownIsRefusedAsNotOnScreen() async throws {
    let (harness, _) = try Self.harnessWithFileRead()
    let hidden = try #require(harness.store.openFileTab(path: "b.swift", in: harness.feature.id))
    harness.model.fileTabReadings[hidden.id] = FileTabReading(
      content: .text(.replacedBlock(before: 2, removed: 1, added: 2, after: 1)),
      isFileGone: true,
    )

    let reply = await harness.messageSource.ask(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: ControlID.worktree(harness.feature.id),
          path: "b.swift",
          side: .onDisk,
          lines: 3...3,
          text: "Why?",
        )
      )
    )

    #expect(reply == .refused(.tabNotShown(id: hidden.id)))
  }

  @Test func addingRightAfterTheFileChangesQuotesItsNewLines() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    try "hello\ntwo\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil {
      if case .text(let rows) = harness.model.fileTabReadings[tab.id]?.content {
        rows.lines.contains { $0.text == "two" }
      } else {
        false
      }
    }
    try "added\nhello\ntwo\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)

    _ = await harness.model.answer(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: tab.path,
          side: .onDisk,
          lines: 2...2,
          text: "Why?",
        )
      )
    )

    #expect(harness.model.reviewComments(in: main.id).first?.quote == ["hello"])
  }

  @Test func blankTextIsRefusedBeforeTheTabIsLookedFor() async throws {
    let (harness, _) = try Self.harnessWithFileRead()

    let reply = await harness.messageSource.ask(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: "missing.swift",
          side: .onDisk,
          lines: 3...3,
          text: "  ",
        )
      )
    )

    #expect(reply == .refused(.invalidValue(key: "text", value: "  ")))
  }

  @Test func anEditTheWatcherHasNotNoticedIsQuotedAsTheFileNowReads() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    try "added\nhello\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )

    _ = await harness.model.answer(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: tab.path,
          side: .onDisk,
          lines: 1...1,
          text: "Why?",
        )
      )
    )

    #expect(harness.model.reviewComments(in: main.id).first?.quote == ["added"])
  }

  @Test func aFileThatReadsAsBinaryOnTheFreshReadIsRefusedAsANotice() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    try Data([0, 1, 2, 0, 255, 0]).write(to: main.path.appending(path: "README.md"))

    let reply = await harness.model.answer(
      .addReviewComment(
        ReviewCommentOrder(
          worktreeID: nil,
          path: tab.path,
          side: .onDisk,
          lines: 1...1,
          text: "Why?",
        )
      )
    )

    #expect(reply == .refused(.fileTabShowsNotice(id: tab.id)))
  }
}
