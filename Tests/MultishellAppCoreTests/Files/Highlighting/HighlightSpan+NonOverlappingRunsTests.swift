import Testing

@testable import MultishellAppCore

@Suite
struct HighlightSpanNonOverlappingRunsTests {
  @Test func overlappingSpansBecomeRunsInTextOrderWithTheLaterSpanWinning() {
    let spans = [
      HighlightSpan(range: 6..<9, role: .string),
      HighlightSpan(range: 0..<10, role: .comment),
      HighlightSpan(range: 2..<4, role: .keyword),
      HighlightSpan(range: 8..<14, role: .number),
    ]

    let runs = HighlightSpan.nonOverlappingRuns(spans, length: 12)

    #expect(
      runs == [
        HighlightSpan(range: 0..<2, role: .comment), HighlightSpan(range: 2..<4, role: .keyword),
        HighlightSpan(range: 4..<8, role: .comment), HighlightSpan(range: 8..<12, role: .number),
      ]
    )
  }

  @Test func aPlainSpanClearsWhatItCoversAndLeavesNoRunOfItsOwn() {
    let spans = [
      HighlightSpan(range: 0..<10, role: .string),
      HighlightSpan(range: 2..<8, role: .plain),
      HighlightSpan(range: 4..<6, role: .keyword),
    ]

    let runs = HighlightSpan.nonOverlappingRuns(spans, length: 10)

    #expect(
      runs == [
        HighlightSpan(range: 0..<2, role: .string), HighlightSpan(range: 4..<6, role: .keyword),
        HighlightSpan(range: 8..<10, role: .string),
      ]
    )
  }
}
