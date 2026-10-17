import Testing

@testable import MultishellAppCore

@Suite
struct WordDiffTests {
  private static func marked(_ old: String, _ new: String) -> (old: [String], new: [String]) {
    guard case .changed(let oldParts, let newParts) = WordDiff.changedParts(from: old, to: new)
    else {
      Issue.record("not compared as an edit")
      return ([], [])
    }
    let text = { (string: String, ranges: [Range<Int>]) in
      ranges.map { String(decoding: Array(string.utf16)[$0], as: UTF16.self) }
    }
    return (text(old, oldParts), text(new, newParts))
  }

  @Test func aRenamedWordIsMarkedWholeOnBothSides() {
    let parts = Self.marked(
      "  init(listing: FileTreeListing, reusing previous: Self?) {",
      "  init(listing: FileTreeListing, reusingChangesOf previous: Self?) {",
    )

    #expect(parts.old == ["reusing"])
    #expect(parts.new == ["reusingChangesOf"])
  }

  @Test func wordsAddedOnOneSideAreMarkedThereAlone() {
    let parts = Self.marked("for change in changes {", "for change in Self.changes {")

    #expect(parts.old.isEmpty)
    #expect(parts.new == ["Self."])
  }

  @Test func textRewrittenWholeIsARewriteAndNoEdit() {
    #expect(
      WordDiff.changedParts(from: "let total = counts[path]", to: "return nil") == .rewritten
    )
  }

  @Test func rangesCountUTF16UnitsAndKeepAccentsWithTheirLetter() {
    let parts = Self.marked("nom = \"cafe\u{301}\" // 名前", "nom = \"the\u{301}\" // 名前")

    #expect(parts.old == ["cafe\u{301}"])
    #expect(parts.new == ["the\u{301}"])
  }

  @Test func longTextRewrittenWholeIsTooLongToCompareRatherThanDiffedAtLength() {
    let old = (0..<3_000).map { "old\($0)" }.joined(separator: " ")
    let new = (0..<3_000).map { "new\($0)" }.joined(separator: " ")

    #expect(WordDiff.changedParts(from: old, to: new) == .tooLongToCompare)
  }

  @Test func comparisonsDrawOnOneSharedBudgetAndStopWhenItIsSpent() {
    var budget = 30

    let first = WordDiff.changedParts(from: "a b c d", to: "a x y d", pairBudget: &budget)
    let second = WordDiff.changedParts(
      from: "a b c d e f g",
      to: "a t u v w x g",
      pairBudget: &budget,
    )

    #expect(first != .tooLongToCompare)
    #expect(budget < 30)
    #expect(second == .tooLongToCompare)
  }
}
