import Testing

@testable import MultishellAppCore

@Suite
struct FlowLinesTests {
  @Test func itemsThatFitShareOneLine() {
    #expect(FlowLines(widths: [100, 100, 100], maxWidth: 320, spacing: 10).lines == [0..<3])
  }

  @Test func anItemPastTheWidthStartsTheNextLine() {
    #expect(
      FlowLines(widths: [100, 100, 100], maxWidth: 300, spacing: 10).lines == [0..<2, 2..<3]
    )
  }

  @Test func anItemWiderThanTheWidthHasALineToItself() {
    #expect(
      FlowLines(widths: [50, 400, 50], maxWidth: 300, spacing: 10).lines == [0..<1, 1..<2, 2..<3]
    )
  }

  /// Widths whose sum, added in another order, comes out above the running one.
  @Test func aLineOfferedExactlyItsOwnWidthStaysOneLine() throws {
    for widths in [[147.006, 124.516, 131.384], [127.17, 193.304]] {
      let measured = FlowLines(widths: widths, maxWidth: .infinity, spacing: 8)
      let line = try #require(measured.lineWidths.first)
      #expect(
        FlowLines(widths: widths, maxWidth: line, spacing: 8).lines == [0..<widths.count],
        "\(widths)",
      )
    }
  }

  @Test func anItemWiderThanTheWidthIsShownNoWiderThanIt() {
    let flow = FlowLines(widths: [50, 400], maxWidth: 300, spacing: 10)
    #expect(flow.shownWidth(of: 400) == 300)
    #expect(flow.shownWidth(of: 50) == 50)
    #expect(flow.isShownNarrower(than: 400))
    #expect(!flow.isShownNarrower(than: 300))
  }

  @Test func noItemsMakeNoLines() {
    #expect(FlowLines(widths: [], maxWidth: 300, spacing: 10).lines.isEmpty)
  }
}
