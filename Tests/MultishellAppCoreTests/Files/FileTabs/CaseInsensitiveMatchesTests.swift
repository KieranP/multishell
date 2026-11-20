import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct CaseInsensitiveMatchesTests {
  private static func foundationRanges(of findText: String, in text: String) -> [Range<Int>] {
    let searched = text as NSString
    var ranges: [Range<Int>] = []
    var from = 0
    while from < searched.length {
      let found = searched.range(
        of: findText,
        options: [.caseInsensitive],
        range: NSRange(location: from, length: searched.length - from),
      )
      guard found.location != NSNotFound else { break }
      ranges.append(found.location..<NSMaxRange(found))
      from = NSMaxRange(found)
    }
    return ranges
  }

  @Test(arguments: [
    ("e", "Let me see EVERY e\nand E."),
    ("aa", "aaaaa"),
    (" ", "  indented\n\tand  spaced "),
    ("Foo[1]", "foo[1] FOO[1] fOo[2]"),
    ("@Z", "@z @Z @[ `z"),
    ("x", ""),
    ("longer than the text", "short"),
    ("é", "Café CAFÉ cafe\u{301}"),
    ("ss", "Straße STRASSE strasse"),
    ("ok", "naïve ok OK"),
    ("k", "\u{212A}elvin k K"),
  ])
  func everyMatchIsWhereFoundationsCaseInsensitiveSearchFindsIt(
    findText: String,
    text: String,
  ) {
    #expect(
      CaseInsensitiveMatches.ranges(of: findText, in: text)
        == Self.foundationRanges(of: findText, in: text)
    )
  }

  @Test func anEmptyFindTextMatchesNothing() {
    #expect(CaseInsensitiveMatches.ranges(of: "", in: "text").isEmpty)
  }
}
