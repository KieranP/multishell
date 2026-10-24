import Testing

@testable import MultishellGitKit

@Suite
struct RawNumstatParserTests {
  private static let zeros = String(repeating: "0", count: 40)
  private static let sha = String(repeating: "a", count: 40)

  private static func raw(_ letter: String, _ path: String) -> String {
    ":100644 100644 \(sha) \(zeros) \(letter)\u{0}\(path)\u{0}"
  }

  @Test func eachCountedPathTakesItsRawLetter() {
    let output =
      Self.raw("M", "a.txt") + Self.raw("A", "new.txt") + Self.raw("D", "gone.txt")
      + "2\t1\ta.txt\u{0}3\t0\tnew.txt\u{0}0\t4\tgone.txt\u{0}"

    #expect(
      Set(RawNumstatParser.parse(output)) == [
        StatusChange(
          path: "a.txt",
          kind: .modified,
          lines: .counted(insertions: 2, deletions: 1),
        ),
        StatusChange(path: "new.txt", kind: .added, lines: .counted(insertions: 3, deletions: 0)),
        StatusChange(
          path: "gone.txt",
          kind: .deleted,
          lines: .counted(insertions: 0, deletions: 4),
        ),
      ]
    )
  }

  /// What `diff-index` prints for a file whose stat alone moved: a raw record, no count.
  @Test func aRawRecordWithNoCountIsNoChange() {
    #expect(RawNumstatParser.parse(Self.raw("M", "touched.txt")) == [])
  }

  @Test func aPathKeepsItsTabsNewlinesAndLeadingColon() {
    let path = ":odd\tname\nhere.txt"
    let output = Self.raw("T", path) + "-\t-\t\(path)\u{0}"

    #expect(
      RawNumstatParser.parse(output) == [
        StatusChange(path: path, kind: .modified, lines: .unscored)
      ]
    )
  }
}
