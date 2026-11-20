import Foundation
import Testing

@testable import MultishellCore

@Suite
struct JSONCommentsTests {
  private static func object(_ text: String) throws -> NSDictionary {
    let data = Data(JSONComments.blanked(in: text).utf8)
    return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
  }

  @Test func lineAndBlockCommentsAreBlankedAndTheRestReadsAsJSON() throws {
    let text = """
      // leading
      {
        "a": 1, // after a value
        /* a block
           over lines */ "b": [2, /* inline */ 3]
      }
      """

    #expect(try Self.object(text) == ["a": 1, "b": [2, 3]])
  }

  @Test func slashesAndQuotesInsideAStringAreKept() throws {
    let text = #"{"url": "https://example.com/a", "quote": "a \"// not\" b", "end": "/* no */"}"#

    #expect(
      try Self.object(text)
        == ["url": "https://example.com/a", "quote": #"a "// not" b"#, "end": "/* no */"]
    )
  }
}
