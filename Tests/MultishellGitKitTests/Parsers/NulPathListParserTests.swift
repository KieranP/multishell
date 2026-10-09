import Testing

@testable import MultishellGitKit

@Suite
struct NulPathListParserTests {
  @Test func pathsAreSplitOnNulAndNotOnNewlines() {
    #expect(NulPathListParser.parse("a.txt\0dir/b c.txt\0") == ["a.txt", "dir/b c.txt"])
    #expect(
      NulPathListParser.parse("odd\nname.txt\0b.txt\0") == ["odd\nname.txt", "b.txt"],
      "the newline is part of the path, not a separator",
    )
    #expect(NulPathListParser.parse("").isEmpty)
  }

  @Test func onlyThePathsWithinTheLimitAreDecoded() {
    let limit = UntrackedLineCounter.fileLimit
    let listing = (1...limit + 3).map { "f\($0).txt" }.joined(separator: "\0")

    #expect(NulPathListParser.parse(listing, limit: limit).count == limit)
  }
}
