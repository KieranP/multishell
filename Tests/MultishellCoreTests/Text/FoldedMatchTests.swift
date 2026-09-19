import Foundation
import Testing

@testable import MultishellCore

@Suite
struct FoldedMatchTests {
  /// Unicode's own folding, not the reader's: `localizedStandardContains`
  /// reads `Locale.current`, which is the machine's and not the data's.
  @Test func caseAndAccentsFoldAndNothingElseDoes() {
    #expect("kieran/rate-limits".foldedContains("LIMITS"))
    #expect("Crème brûlée".foldedContains("creme brulee"))
    #expect("MAIN".foldedContains("main"))
    #expect(!"main".foldedContains("mane"))
    #expect("anything".foldedContains(""), "an empty filter shows everything")
    #expect(!"".foldedContains("x"))
  }

  /// The pair that broke the icon picker under `tr_TR`, kept as the reason
  /// this exists: the dotless I stops an ASCII query matching ASCII data.
  @Test func theLocaleSensitiveFormIsWhatThisAvoids() {
    let turkish = Locale(identifier: "tr_TR")
    #expect(
      "disk volume storage".range(of: "DISK", options: [.caseInsensitive], locale: turkish) == nil)
    #expect("disk volume storage".foldedContains("DISK"))
  }
}
