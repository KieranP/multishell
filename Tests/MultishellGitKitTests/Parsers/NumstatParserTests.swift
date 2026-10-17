import Testing

@testable import MultishellGitKit

@Suite
struct NumstatParserTests {
  @Test func eachPathKeepsItsOwnInsertionsAndDeletions() {
    let output = "12\t3\tSources/App.swift\u{0}0\t7\tREADME.md\u{0}"

    #expect(
      NumstatParser.parse(output) == [
        "Sources/App.swift": .counted(insertions: 12, deletions: 3),
        "README.md": .counted(insertions: 0, deletions: 7),
      ]
    )
  }

  @Test func aBinaryFileIsAFileWithNoLines() {
    let lines = NumstatParser.parse("-\t-\ticon.png\u{0}4\t0\ta.txt\u{0}")

    #expect(lines["icon.png"] == .unscored)
    #expect(lines["a.txt"] == .counted(insertions: 4, deletions: 0))
  }

  /// What a mode change prints.
  @Test func aChangeWithZeroOnBothSidesIsAFileWithNoLines() {
    #expect(NumstatParser.parse("0\t0\tScripts/run.sh\u{0}") == ["Scripts/run.sh": .unscored])
  }

  @Test func aPathKeepsItsTabsAndNewlines() {
    let lines = NumstatParser.parse("1\t2\todd\tname\nhere.txt\u{0}")

    #expect(lines == ["odd\tname\nhere.txt": .counted(insertions: 1, deletions: 2)])
  }

  /// A count that is neither a number nor `-` is not git's output, and
  /// taking it as zero put a file with no lines to count on the badge.
  @Test func anOddRecordCountsNothingAtAll() {
    for record in ["", "  ", "x\ty\tz", "1", "1\t2", "\t\t", "1\t2\t", "1\t-\ta.txt"] {
      #expect(NumstatParser.parse(record + "\u{0}") == [:], "\(record)")
    }
  }
}
