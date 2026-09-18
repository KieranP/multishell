import Testing

@testable import MultishellGitKit

@Suite
struct DiffStatParserTests {
  @Test func sumsBothColumns() {
    let output = "12\t3\tSources/App.swift\n0\t7\tREADME.md\n"
    let stat = DiffStatParser.parse(output)
    #expect(stat.insertions == 12)
    #expect(stat.deletions == 10)
  }

  @Test func aBinaryFileCountsNoLinesAndIsCountedAsAFileInstead() {
    let stat = DiffStatParser.parse("-\t-\ticon.png\n4\t0\ta.txt\n")
    #expect(stat.insertions == 4)
    #expect(stat.deletions == 0)
    #expect(stat.unscored == 1)
  }

  /// What a mode change and a pure rename both print.
  @Test func aChangeWithZeroOnBothSidesIsCountedAsAFile() {
    #expect(DiffStatParser.parse("0\t0\tScripts/run.sh\n").unscored == 1)
    #expect(DiffStatParser.parse("12\t3\ta.swift\n").unscored == 0)
  }

  /// A rename with `-z` off still puts the arrow in the path field.
  @Test func aRenamedPathDoesNotBreakTheColumns() {
    let stat = DiffStatParser.parse("1\t1\told.swift => new.swift\n")
    #expect(stat.insertions == 1 && stat.deletions == 1)
  }

  @Test func aRowWithNoPathIsNotCountedAsAFile() {
    let stat = DiffStatParser.parse("1\t2\t\n3\t4\ta.txt\n")
    #expect(stat.insertions == 3 && stat.deletions == 4)
    #expect(stat.unscored == 0)
  }

  /// A count that is neither a number nor `-` is not git's output, and
  /// taking it as zero put a file with no lines to count on the badge.
  @Test func anOddLineCountsNothingAtAll() {
    for line in ["", "  ", "x\ty\tz", "1", "1\t2", "\t\t", "1\t2\t", "1\t-\ta.txt"] {
      let stat = DiffStatParser.parse(line + "\n")
      #expect(
        stat.insertions == 0 && stat.deletions == 0 && stat.unscored == 0,
        "\(line) counted \(stat)")
    }
  }
}
