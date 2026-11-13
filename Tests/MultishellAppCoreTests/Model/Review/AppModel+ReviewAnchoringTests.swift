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
    let comment = ReviewComment(
      path: "README.md",
      side: .onDisk,
      scope: .modified,
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
}
