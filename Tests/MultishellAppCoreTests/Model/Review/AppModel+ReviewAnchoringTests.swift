import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelReviewAnchoringTests {
  @Test func aFileTabsReadMovesACommentWithTheLinesItQuotes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    _ = try await harness.rowsArrive(in: tab.id)
    let comment = ReviewComment.sample(
      path: "README.md",
      lines: 1...1,
      quote: ["hello"],
      text: "Say more.",
    )
    harness.model.addReviewComment(comment, in: main.id)

    try "top\nhello\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { harness.model.reviewComments(in: main.id).first?.lines == 2...2 }
    #expect(harness.model.reviewComments(in: main.id).first?.lines == 2...2)
  }

  @Test func aCommentQuotingALineCutForDisplayMovesWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    let long = String(repeating: "x", count: 12_000)
    let readme = main.path.appending(path: "README.md")
    try "hello\n\(long)\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)
    _ = try await harness.rowsArrive(in: tab.id)
    let comment = ReviewComment.sample(
      path: "README.md",
      lines: 2...2,
      quote: [long],
      text: "Split this.",
    )
    harness.model.addReviewComment(comment, in: main.id)

    try "top\nhello\n\(long)\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(tab.id)

    try await waitUntil { harness.model.reviewComments(in: main.id).first?.lines != 2...2 }
    #expect(harness.model.reviewComments(in: main.id).first?.lines == 3...3)
  }
}
