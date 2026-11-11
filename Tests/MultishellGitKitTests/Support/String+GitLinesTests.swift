import Testing

@testable import MultishellGitKit

@Suite
struct StringGitLinesTests {
  @Test func linesSplitOnANewlineAloneAndLoseACarriageReturnBeforeIt() {
    #expect("a\u{2028}b\r\nc\n\n".gitLines == ["a\u{2028}b", "c"])
  }
}
