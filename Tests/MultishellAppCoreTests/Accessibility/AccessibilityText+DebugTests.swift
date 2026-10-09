import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct AccessibilityTextDebugTests {
  private let kilobyte = DebugValueText.memory(1_024)
  private let twoKilobytes = DebugValueText.memory(2_048)

  private func memoryRow(
    _ source: DebugMemoryRow.Source = .unattributed, processCount: Int? = 2,
    selfMemory: UInt64? = 1_024, terminalRow: DebugTerminalRow? = nil
  ) -> DebugMemoryRow {
    DebugMemoryRow(
      source: source, title: "Shell", subtitle: "acme / main", processCount: processCount,
      selfMemory: selfMemory, totalMemory: 2_048, barFraction: 1, terminalRow: terminalRow,
      processRows: [])
  }

  private func processRow(depth: Int) -> DebugProcessRow {
    DebugProcessRow(
      process: .sample(pid: 10, footprint: 1_024), depth: depth, totalMemory: 2_048)
  }

  @Test func theQuickStatsAreSpokenWithTheirUnits() {
    let stats = DebugQuickStats(
      history: .of([
        DebugSample.sample(
          sequence: 0, framesPerSecond: 1, appCPUPercent: 30, childrenCPUPercent: 4)
      ]))
    let spoken = AccessibilityText.debugQuickStats(stats)

    #expect(spoken.hasPrefix("Debug Info, 1 frame per second, 34% CPU, "))
    #expect(spoken.hasSuffix(" memory"))
  }

  @Test func theQuickStatsBeforeAnySampleAreSpokenAsTheirNameAlone() {
    #expect(
      AccessibilityText.debugQuickStats(DebugQuickStats(history: DebugHistory())) == "Debug Info")
  }

  @Test func aMemoryRowIsSpokenWithItsCountsAndWhetherItIsOpen() {
    #expect(
      AccessibilityText.debugMemoryRow(memoryRow(), disclosure: .collapsed)
        == "Shell, acme / main, 2 processes, \(kilobyte) self, \(twoKilobytes) total, collapsed")
    #expect(
      AccessibilityText.debugMemoryRow(memoryRow(), disclosure: .expanded)
        .hasSuffix(", expanded"))
  }

  @Test func aRowThatCannotOpenSaysNothingAboutOpening() {
    let spoken = AccessibilityText.debugMemoryRow(
      memoryRow(.total, processCount: nil, selfMemory: nil), disclosure: .notExpandable)
    #expect(spoken == "Shell, acme / main, \(twoKilobytes) total")
  }

  @Test func aProcessIsSpokenWithItsDepthOnlyWhereSomethingStartedIt() {
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 0), under: memoryRow())
        == "p10, \(kilobyte) self, \(twoKilobytes) total")
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 2), under: memoryRow())
        == "p10, started by the process above, 2 deep, \(kilobyte) self, \(twoKilobytes) total")
  }

  @Test func aShellAtTheTopOfATabIsSpokenAsRunningInTheTerminalAboveIt() {
    let tabWithTerminal = memoryRow(
      terminalRow: DebugTerminalRow(selfMemory: 1_024, totalMemory: 2_048))
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 0), under: tabWithTerminal)
        == "p10, runs in the terminal above, \(kilobyte) self, \(twoKilobytes) total")
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 2), under: tabWithTerminal)
        == "p10, started by the process above, 2 deep, \(kilobyte) self, \(twoKilobytes) total")
  }

  @Test func aTerminalIsSpokenWithWhatItHoldsAndWhatItsShellsHoldWithIt() {
    #expect(
      AccessibilityText.debugTerminalRow(DebugTerminalRow(selfMemory: 1_024, totalMemory: 2_048))
        == "Terminal, \(kilobyte) self, \(twoKilobytes) total")
  }
}
