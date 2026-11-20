import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct DiffDisplayTextDiffCopyTests {
  private static let text = DiffDisplayText(
    [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "one"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "two"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "TWO"),
      DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "three"),
    ],
    marksStaging: true,
  )

  private static let block = DiffDisplayText(
    [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old a"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old b"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new a"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "new b"),
      DiffLine(kind: .context, oldNumber: 4, newNumber: 4, text: "tail"),
    ],
    marksStaging: true,
  )

  @Test func aSelectionInsideUnchangedLinesCopiesPlainText() {
    #expect(Self.text.diffCopy(selections: [1..<3]) == "ne")
    #expect(Self.text.diffCopy(selections: [0..<1, 12..<17]) == "o\nthree")
  }

  @Test func partOfOneChangedLineCopiesOnlyThatPart() {
    #expect(Self.block.diffCopy(selections: [7..<10]) == "d a")
    #expect(Self.block.diffCopy(selections: [19..<22]) == "w a")
    #expect(Self.block.diffCopy(selections: [Self.block.range(ofRow: 3)]) == "new a")
  }

  @Test func linesAllRemovedOrAllAddedCopyAsSelectedWithoutMarks() {
    #expect(Self.block.diffCopy(selections: [7..<14]) == "d a\nold")
    #expect(Self.block.diffCopy(selections: [19..<26]) == "w a\nnew")
  }

  @Test func oneSideOfAChangeWithItsContextCopiesAsSelectedWithoutMarks() {
    #expect(Self.block.diffCopy(selections: [2..<14]) == "ep\nold a\nold")
    #expect(Self.block.diffCopy(selections: [24..<31]) == "ew b\nta")
    #expect(Self.text.diffCopy(selections: [2..<6]) == "e\ntw")
  }

  @Test func removedAndAddedLinesTogetherCopyWholeLinesAsGitDiffPrintsThem() {
    #expect(Self.block.diffCopy(selections: [7..<20]) == "-old a\n-old b\n+new a\n")
    #expect(
      Self.block.diffCopy(selections: [2..<31])
        == " keep\n-old a\n-old b\n+new a\n+new b\n tail\n"
    )
    #expect(Self.text.diffCopy(selections: [5..<6, 9..<10]) == "-two\n+TWO\n")
  }

  @Test func aLineCutForDisplayCopiesWhole() {
    let long = String(repeating: "a", count: 10_000) + "tail"
    let text = DiffDisplayText(
      [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: long),
        DiffLine(kind: .context, oldNumber: 2, newNumber: 2, text: "next"),
        DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: long),
      ],
      marksStaging: true,
    )
    let firstRow = text.range(ofRow: 0)

    #expect(text.diffCopy(selections: [firstRow]) == long)
    #expect(text.diffCopy(selections: [9_998..<text.rowStarts[1] + 2]) == "aatail\nne")
    #expect(text.diffCopy(selections: [0..<2]) == "aa")
    #expect(text.diffCopy(selections: [text.range(ofRow: 3)]) == long)
    #expect(
      text.diffCopy(selections: [text.rowStarts[2]..<text.range(ofRow: 3).upperBound])
        == "-old\n+" + long + "\n"
    )
    #expect(text.plainCopy(selections: [firstRow]) == long)
  }

  @Test func aRangeEndingAtALinesStartDoesNotReachIt() {
    #expect(Self.text.diffCopy(selections: [0..<4]) == "one\n")
    #expect(Self.text.diffCopy(selections: [4..<8]) == "two\n")
  }

  @Test func aSplitSideCopiesPlainTextWithItsPaddingLeftOut() {
    let side = SplitDiff(
      [
        DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
        DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "old a"),
        DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "old b"),
        DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "new a"),
        DiffLine(kind: .context, oldNumber: 4, newNumber: 3, text: "tail"),
      ],
      marksStaging: true,
    ).onDisk

    #expect(side.plainCopy(selections: [0..<side.string.utf16.count]) == "keep\nnew a\ntail")
  }
}
