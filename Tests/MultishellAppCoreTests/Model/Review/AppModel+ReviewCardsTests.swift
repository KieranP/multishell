import Foundation
import Observation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelReviewCardsTests {
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

  @Test func aRevealWaitsForTheTabsRowsThenIsTakenOnceWhetherOrNotItsCardIsDrawn() async throws {
    let (harness, _) = Harness.withOnePane()
    let comment = Self.comment()
    harness.model.addReviewComment(comment, in: harness.main.id)
    let tab = try #require(harness.store.openFileTab(path: comment.path, in: harness.main.id))
    await harness.model.selectReviewComment(comment.id, in: harness.main.id)
    #expect(harness.model.takeReviewCardReveal(tab.id) == nil)

    let rows = FileTabRows(
      lines: [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "let z = 0")],
      marksStaging: true,
    )
    harness.model.fileTabReadings[tab.id] = FileTabReading(content: .text(rows), isFileGone: false)

    #expect(harness.model.takeReviewCardReveal(tab.id) == .comment(comment.id))
    #expect(harness.model.takeReviewCardReveal(tab.id) == nil)
  }

  @Test func takingWhenNoRevealWasAskedRedrawsNothing() throws {
    let harness = Harness()
    let tab = try #require(harness.store.openFileTab(path: "a.swift", in: harness.main.id))
    let rows = FileTabRows(
      lines: [DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a")],
      marksStaging: true,
    )
    harness.model.fileTabReadings[tab.id] = FileTabReading(content: .text(rows), isFileGone: false)
    let wrote = AtomicFlag()
    withObservationTracking {
      _ = harness.model.reviewCardRevealRequests
    } onChange: {
      wrote.raise()
    }

    _ = harness.model.takeReviewCardReveal(tab.id)

    #expect(!wrote.raised)
  }
}
