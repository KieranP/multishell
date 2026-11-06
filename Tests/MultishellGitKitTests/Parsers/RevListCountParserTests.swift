import Testing

@testable import MultishellGitKit

@Suite
struct RevListCountParserTests {
  @Test func aCountWithItsNewlineIsTheNumber() {
    #expect(RevListCountParser.parse("12\n") == 12)
  }

  @Test func anEmptyOrWordyAnswerIsNoCount() {
    #expect(RevListCountParser.parse("") == nil)
    #expect(RevListCountParser.parse("fatal: bad revision\n") == nil)
  }
}
