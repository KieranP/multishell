import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct CaseInsensitiveMatchesTests {
  private static func fastestJudgement(of findText: String, in text: String) -> Duration {
    (0..<3).map { _ in
      ContinuousClock().measure {
        #expect(CaseInsensitiveMatches.ranges(of: findText, in: text) == [])
      }
    }.min() ?? .zero
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
        == CaseInsensitiveMatches.foundationRanges(of: findText, in: text)
    )
  }

  @Test func aLongFindTextMissingFromARepetitiveMebibyteCostsUnderTenTimesAShortOne() {
    let text = String(repeating: "=", count: 1 << 20)
    let short = Self.fastestJudgement(of: String(repeating: "=", count: 10) + "x", in: text)
    let long = Self.fastestJudgement(of: String(repeating: "=", count: 10_000) + "x", in: text)

    // A search costing text times find text took over 2,000 times the short one's;
    // against the same run, the bound holds on a runner of any speed.
    #expect(long < short * 10, "\(long) against \(short)")
  }

  @Test func anEmptyFindTextMatchesNothing() {
    #expect(CaseInsensitiveMatches.ranges(of: "", in: "text").isEmpty)
  }
}
