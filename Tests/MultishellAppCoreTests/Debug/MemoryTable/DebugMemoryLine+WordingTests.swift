import Testing

@testable import MultishellAppCore

@Suite
struct DebugMemoryLineWordingTests {
  private func line(
    _ source: DebugMemoryLine.Source, subtitle: String = "acme / main", processCount: Int?,
    selfMemory: UInt64?
  ) -> DebugMemoryLine {
    DebugMemoryLine(
      source: source, title: "Shell", subtitle: subtitle, processCount: processCount,
      selfMemory: selfMemory, totalMemory: selfMemory, barFraction: 0, processLines: [])
  }

  @Test func theTotalRowLeavesItsCountAndSelfEmptyWhereATabWithoutThemShowsADash() {
    let total = line(.total, subtitle: "", processCount: nil, selfMemory: nil)
    let unplaced = line(.unattributed, processCount: nil, selfMemory: nil)

    #expect(total.processCountText == "")
    #expect(total.selfMemoryText == "")
    #expect(unplaced.processCountText == "–")
    #expect(unplaced.selfMemoryText == "–")
  }

  @Test func aNarrowRowSaysItsSubtitleCountAndSelfUnderItsName() {
    let placed = line(.unattributed, processCount: 2, selfMemory: 1_024)
    #expect(placed.stackedCaptions.first?.hasPrefix("acme / main · 2 processes · ") == true)
    #expect(placed.stackedCaptions.first?.hasSuffix(" self") == true)

    #expect(
      line(.unattributed, processCount: nil, selfMemory: nil).stackedCaptions == ["acme / main"])
    #expect(line(.total, subtitle: "", processCount: nil, selfMemory: nil).stackedCaptions.isEmpty)
  }
}
