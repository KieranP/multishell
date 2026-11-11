import Testing

@testable import MultishellCore

@Suite
struct StringJSONCommentsTests {
  @Test func aLineCommentEndsAtItsLineWhateverTheLineEnding() {
    let unix = "{\n  // steering\n  \"a\": 1\n}\n"
    let windows = "{\r\n  // steering\r\n  \"a\": 1\r\n}\r\n"

    #expect(unix.withoutJSONComments == "{\n  \n  \"a\": 1\n}\n")
    #expect(windows.withoutJSONComments == "{\r\n  \r\n  \"a\": 1\r\n}\r\n")
  }

  @Test func aURLsSlashesInAStringAreText() {
    let text = #"{"url": "https://example.com"} // note"#

    #expect(text.withoutJSONComments == #"{"url": "https://example.com"} "#)
  }

  @Test func aStringStartingWithACombiningMarkIsStillAString() {
    let text = #"{"a": "\#u{0301}see https://x", "b": 1} // note"#

    #expect(text.withoutJSONComments == #"{"a": "\#u{0301}see https://x", "b": 1} "#)
  }
}
