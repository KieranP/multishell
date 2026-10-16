import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct StringPrefoldedMatchTests {
  @Test(arguments: [
    ("kieran/rate-limits", "LIMITS"), ("Crème brûlée", "creme brulee"), ("main", "mane"),
    ("anything", ""), ("", "x"), ("caf\u{E9}.txt", "cafe\u{301}"),
    ("\u{1112}\u{1161}\u{11AB}.md", "\u{D55C}"), ("docs/\u{D55C}.md", "\u{1112}\u{1161}\u{11AB}"),
  ])
  func prefoldedTextMatchesWhereFoldedContainsDoes(text: String, filter: String) {
    #expect(
      text.foldedForMatching.prefoldedContains(filter.foldedForMatching)
        == text.foldedContains(filter)
    )
  }
}
