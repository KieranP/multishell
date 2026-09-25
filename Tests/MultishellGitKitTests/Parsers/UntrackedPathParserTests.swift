import Testing

@testable import MultishellGitKit

@Suite
struct UntrackedPathParserTests {
  @Test func pathsAreSplitOnNulAndNotOnNewlines() {
    #expect(
      UntrackedPathParser.parse("a.txt\0dir/b c.txt\0", limit: 10) == ["a.txt", "dir/b c.txt"])
    #expect(UntrackedPathParser.parse("odd\nname.txt\0", limit: 10) == ["odd\nname.txt"])
    #expect(UntrackedPathParser.parse("", limit: 10).isEmpty)
  }

  @Test func onlyTheFilesItWillReadAreDecoded() {
    let limit = UntrackedLineCounter.fileLimit
    let listing = (1...limit + 3).map { "f\($0).txt" }.joined(separator: "\0")

    #expect(UntrackedPathParser.parse(listing, limit: limit).count == limit)
  }
}
