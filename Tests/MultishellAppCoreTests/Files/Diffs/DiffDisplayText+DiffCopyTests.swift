import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextDiffCopyTests {
  private static let text = DiffDisplayText([
    DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "one"),
    DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "two"),
    DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "TWO"),
    DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "three"),
  ])

  @Test func aSelectionInsideUnchangedLinesCopiesPlainText() {
    #expect(Self.text.diffCopy(selections: [1..<3]) == "ne")
    #expect(Self.text.diffCopy(selections: [0..<1, 12..<17]) == "o\nthree")
  }

  @Test func aSelectionTouchingAChangeCopiesWholeLinesAsGitDiffPrintsThem() {
    #expect(Self.text.diffCopy(selections: [2..<6]) == " one\n-two\n")
    #expect(
      Self.text.diffCopy(selections: [8..<10, 15..<17]) == "+TWO\n three\n"
    )
  }

  @Test func aRangeEndingAtALinesStartDoesNotReachIt() {
    #expect(Self.text.diffCopy(selections: [0..<4]) == "one\n")
  }

  @Test func aSplitSideCopiesPlainTextWithItsPaddingLeftOut() {
    let side = SplitDiff([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old a"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old b"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new a"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 3, text: "tail"),
    ]).onDisk

    #expect(side.plainCopy(selections: [0..<side.string.utf16.count]) == "keep\nnew a\ntail")
  }
}
