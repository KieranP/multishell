import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct AccessibilityTextDebugTests {
  private let kilobyte = DebugValueText.memory(1_024)
  private let twoKilobytes = DebugValueText.memory(2_048)

  private func memoryLine(
    _ source: DebugMemoryLine.Source = .unattributed, processCount: Int? = 2,
    selfMemory: UInt64? = 1_024
  ) -> DebugMemoryLine {
    DebugMemoryLine(
      source: source, title: "Shell", subtitle: "acme / main", processCount: processCount,
      selfMemory: selfMemory, totalMemory: 2_048, barFraction: 1, processLines: [])
  }

  private func processLine(depth: Int) -> DebugProcessLine {
    DebugProcessLine(
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
      AccessibilityText.debugMemoryLine(memoryLine(), disclosure: .collapsed)
        == "Shell, acme / main, 2 processes, \(kilobyte) self, \(twoKilobytes) total, collapsed")
    #expect(
      AccessibilityText.debugMemoryLine(memoryLine(), disclosure: .expanded)
        .hasSuffix(", expanded"))
  }

  @Test func aRowThatCannotOpenSaysNothingAboutOpening() {
    let spoken = AccessibilityText.debugMemoryLine(
      memoryLine(.total, processCount: nil, selfMemory: nil), disclosure: .notExpandable)
    #expect(spoken == "Shell, acme / main, \(twoKilobytes) total")
  }

  @Test func aProcessIsSpokenWithItsDepthOnlyWhereSomethingStartedIt() {
    #expect(
      AccessibilityText.debugProcessLine(processLine(depth: 0))
        == "p10, \(kilobyte) self, \(twoKilobytes) total")
    #expect(
      AccessibilityText.debugProcessLine(processLine(depth: 2))
        == "p10, started by the process above, 2 deep, \(kilobyte) self, \(twoKilobytes) total")
  }
}
