import Testing

@testable import MultishellAppCore

@Suite
struct FlowRowsTests {
  @Test func itemsThatFitShareOneLine() {
    #expect(FlowRows(widths: [100, 100, 100], maxWidth: 320, spacing: 10).lines == [0..<3])
  }

  @Test func anItemPastTheWidthStartsTheNextLine() {
    #expect(
      FlowRows(widths: [100, 100, 100], maxWidth: 300, spacing: 10).lines == [0..<2, 2..<3]
    )
  }

  @Test func anItemWiderThanTheWidthHasALineToItself() {
    #expect(
      FlowRows(widths: [50, 400, 50], maxWidth: 300, spacing: 10).lines == [0..<1, 1..<2, 2..<3]
    )
  }

  /// Widths whose sum, added in another order, comes out above the running one.
  @Test func aLineOfferedExactlyItsOwnWidthStaysOneLine() throws {
    for widths in [[147.006, 124.516, 131.384], [127.17, 193.304]] {
      let measured = FlowRows(widths: widths, maxWidth: .infinity, spacing: 8)
      let line = try #require(measured.lineWidths.first)
      #expect(
        FlowRows(widths: widths, maxWidth: line, spacing: 8).lines == [0..<widths.count],
        "\(widths)",
      )
    }
  }

  @Test func anItemWiderThanTheWidthIsShownNoWiderThanIt() {
    let rows = FlowRows(widths: [50, 400], maxWidth: 300, spacing: 10)
    #expect(rows.shownWidth(of: 400) == 300)
    #expect(rows.shownWidth(of: 50) == 50)
    #expect(rows.isShownNarrower(than: 400))
    #expect(!rows.isShownNarrower(than: 300))
  }

  @Test func noItemsMakeNoLines() {
    #expect(FlowRows(widths: [], maxWidth: 300, spacing: 10).lines.isEmpty)
  }
}
