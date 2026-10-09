import Testing

@testable import MultishellAppCore

@Suite
struct DebugMemoryRowWordingTests {
  private func row(
    _ source: DebugMemoryRow.Source,
    processCount: Int?,
    selfMemory: UInt64?,
    subtitle: String = "acme / main",
  ) -> DebugMemoryRow {
    DebugMemoryRow(
      source: source,
      title: "Shell",
      subtitle: subtitle,
      processCount: processCount,
      selfMemory: selfMemory,
      totalMemory: selfMemory,
      barFraction: 0,
      terminalRow: nil,
      processRows: [],
    )
  }

  @Test func theTotalRowLeavesItsCountAndSelfEmptyWhereATabWithoutThemShowsADash() {
    let total = row(.total, processCount: nil, selfMemory: nil, subtitle: "")
    let unplaced = row(.unattributed, processCount: nil, selfMemory: nil)

    #expect(total.processCountText == "")
    #expect(total.selfMemoryText == "")
    #expect(unplaced.processCountText == "–")
    #expect(unplaced.selfMemoryText == "–")
  }

  @Test func aNarrowRowSaysItsSubtitleCountAndSelfUnderItsName() {
    let placed = row(.unattributed, processCount: 2, selfMemory: 1_024)
    #expect(placed.stackedCaptions.first?.hasPrefix("acme / main · 2 processes · ") == true)
    #expect(placed.stackedCaptions.first?.hasSuffix(" self") == true)

    #expect(
      row(.unattributed, processCount: nil, selfMemory: nil).stackedCaptions == ["acme / main"]
    )
    #expect(row(.total, processCount: nil, selfMemory: nil, subtitle: "").stackedCaptions.isEmpty)
  }

  @Test func aNarrowRowWithNoSubtitleStartsItsCaptionAtItsCount() throws {
    let app = row(.app, processCount: 1, selfMemory: 1_024, subtitle: "")
    let caption = try #require(app.stackedCaptions.first)

    #expect(caption.hasPrefix("1 process · "))
    #expect(caption.hasSuffix(" self"))
  }
}
