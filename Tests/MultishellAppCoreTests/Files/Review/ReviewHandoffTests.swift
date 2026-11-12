import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ReviewHandoffTests {
  private static let store = "Sources/MultishellCore/Store/WorkspaceStore.swift"

  private static func comment(
    _ path: String,
    _ lines: ClosedRange<Int>,
    quote: [String],
    text: String,
    side: DiffSide = .onDisk,
  ) -> ReviewComment {
    ReviewComment(path: path, side: side, scope: .modified, lines: lines, quote: quote, text: text)
  }

  @Test func theDocumentQuotesEachCommentsLinesIndentedUnderItsFileAndLines() {
    let added = Self.comment(
      Self.store,
      806...810,
      quote: [
        "if let value {",
        "  worktrees[index].settingOverrides[key] = value",
        "} else {",
        "  worktrees[index].settingOverrides.removeValue(forKey: key)",
        "}",
      ],
      text: "Use a guard so the nil case reads first.",
    )
    let removed = Self.comment(
      Self.store,
      806...806,
      quote: ["projects[projectIndex(of: worktreeID)].settings[key] = value"],
      text: "Keep the project path for the project scope.",
      side: .committed,
    )

    let document = AgentHandoff.document(
      introduction: ReviewHandoff.introduction,
      entries: ReviewHandoff.entries(of: [added, removed]),
    )

    #expect(
      document == """
        Address each review comment below. Each names a file and lines in this worktree, \
        quotes the code it is about, and says what to change.

        ## Sources/MultishellCore/Store/WorkspaceStore.swift:removed 806 from HEAD

            projects[projectIndex(of: worktreeID)].settings[key] = value

        Keep the project path for the project scope.

        ## Sources/MultishellCore/Store/WorkspaceStore.swift:806-810

            if let value {
              worktrees[index].settingOverrides[key] = value
            } else {
              worktrees[index].settingOverrides.removeValue(forKey: key)
            }

        Use a guard so the nil case reads first.

        """
    )
  }

  @Test func commentsAreOrderedByPathThenLine() {
    let comments = [
      Self.comment("b.swift", 1...1, quote: ["x"], text: "b1"),
      Self.comment("a.swift", 9...9, quote: ["x"], text: "a9"),
      Self.comment("a.swift", 2...3, quote: ["x"], text: "a2"),
    ]

    #expect(ReviewHandoff.entries(of: comments).map(\.text) == ["a2", "a9", "b1"])
  }

  @Test func aCommentWhoseLinesChangedSaysSoAboveItsQuote() {
    var comment = Self.comment("a.swift", 4...4, quote: ["old"], text: "Fix it.")
    comment.noteLinesChanged()

    let entry = ReviewHandoff.entries(of: [comment])[0]

    #expect(entry.heading == "a.swift:4")
    #expect(entry.caveat == "These lines have changed since this comment was written.")
  }

  @Test func theFileIsNamedForTheWorktreeWithItsSlashesMadeHyphens() {
    #expect(
      ReviewHandoff.fileName(forWorktreeNamed: "kp/settings-scope") == "review-kp-settings-scope.md"
    )
  }

  @Test func aLongWorktreeNameStillMakesAFileNameTheDiskTakes() {
    let name = ReviewHandoff.fileName(forWorktreeNamed: String(repeating: "é", count: 300))

    #expect(name.utf8.count <= 255)
    #expect(name.hasSuffix(".md"))
  }

  @Test func removedLinesUnderBranchSayTheyAreTheBaseBranchsNumbers() {
    let removed = ReviewComment(
      path: "a.swift",
      side: .committed,
      scope: .branch,
      lines: 4...5,
      quote: ["x", "y"],
      text: "Why?",
    )

    let entry = ReviewHandoff.entries(of: [removed])[0]

    #expect(entry.heading == "a.swift:removed 4-5 from the base branch")
  }
}
