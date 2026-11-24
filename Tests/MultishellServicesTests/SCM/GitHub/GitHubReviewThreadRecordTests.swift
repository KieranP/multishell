import Foundation
import Testing

@testable import MultishellServices

@Suite
struct GitHubReviewThreadRecordTests {
  @Test func aPageKeepsOnlyItsUnresolvedThreadsAndTheNextCursor() throws {
    let json = Data(GitHubFixtures.reviewThreads(id: "t1", hasNextPage: true).utf8)

    let page = try GitHubReviewThreadRecord.page(from: json)

    #expect(page.threads.map(\.id) == ["t1"])
    #expect(page.next == "c1")
    let comment = try #require(page.threads.first?.comments.first)
    #expect(comment.author == "jt")
    #expect(page.threads.first?.diffHunk == "@@ -1,2 +1,2 @@\n-let a\n+let b")
    #expect(page.threads.first?.line == 12)
  }

  @Test func aCommentKeepsItsMarkupForTheAgentAndItsPlainTextForThePage() throws {
    let json = Data(GitHubFixtures.reviewThreads(id: "t1", hasNextPage: false).utf8)

    let comment = try #require(
      try GitHubReviewThreadRecord.page(from: json).threads.first?.comments.first
    )

    #expect(comment.body.hasPrefix("<a href=\"#\"><img alt=\"P1\""))
    #expect(comment.bodyText == "logic: Guard it.")
  }

  @Test func theLastPageHasNoNextCursor() throws {
    let json = Data(GitHubFixtures.reviewThreads(id: "t2", hasNextPage: false).utf8)

    #expect(try GitHubReviewThreadRecord.page(from: json).next == nil)
  }
}
