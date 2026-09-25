import Testing

@testable import MultishellGitKit

@Suite
struct ChangedPathParserTests {
  /// `-z`, so a path holding a newline arrives whole rather than quoted.
  @Test func changedPathsAreReadFromTheNulSeparatedList() {
    #expect(ChangedPathParser.parse("a.txt\u{0}dir/b.txt\u{0}") == ["a.txt", "dir/b.txt"])
    #expect(ChangedPathParser.parse("") == [])
    #expect(
      ChangedPathParser.parse("odd\nname.txt\u{0}b.txt\u{0}") == ["odd\nname.txt", "b.txt"],
      "the newline is part of the path, not a separator")
  }
}
