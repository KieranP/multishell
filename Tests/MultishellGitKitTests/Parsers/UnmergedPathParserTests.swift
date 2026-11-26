import Testing

@testable import MultishellGitKit

struct UnmergedPathParserTests {
  @Test func aPathListedOnceForEachStageIsKeptOnceInOrder() {
    let output =
      "100644 aaa 1\tsrc/b.js\0100644 bbb 2\tsrc/b.js\0100644 ccc 3\tsrc/b.js\0"
      + "100644 ddd 2\ta.js\0100644 eee 3\ta.js\0"

    #expect(UnmergedPathParser.parse(output) == ["src/b.js", "a.js"])
  }

  @Test func aPathHoldingATabOrNewlineIsKeptWhole() {
    #expect(UnmergedPathParser.parse("100644 aaa 2\tone\ttwo\nthree\0") == ["one\ttwo\nthree"])
  }

  @Test func nothingUnmergedListsNoPaths() {
    #expect(UnmergedPathParser.parse("").isEmpty)
  }
}
