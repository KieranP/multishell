import Testing

@testable import MultishellAppCore

@Suite
struct DebugMemoryRowWordingTests {
  private func row(
    _ source: DebugMemoryRow.Source, subtitle: String = "acme / main", processCount: Int?,
    selfMemory: UInt64?
  ) -> DebugMemoryRow {
    DebugMemoryRow(
      source: source, title: "Shell", subtitle: subtitle, processCount: processCount,
      selfMemory: selfMemory, totalMemory: selfMemory, barFraction: 0, processRows: [])
  }

  @Test func theTotalRowLeavesItsCountAndSelfEmptyWhereATabWithoutThemShowsADash() {
    let total = row(.total, subtitle: "", processCount: nil, selfMemory: nil)
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
      row(.unattributed, processCount: nil, selfMemory: nil).stackedCaptions == ["acme / main"])
    #expect(row(.total, subtitle: "", processCount: nil, selfMemory: nil).stackedCaptions.isEmpty)
  }
}
