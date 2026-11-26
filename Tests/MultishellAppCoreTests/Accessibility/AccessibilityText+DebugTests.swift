import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct AccessibilityTextDebugTests {
  private let kilobyte = DebugValueText.memory(1_024)
  private let twoKilobytes = DebugValueText.memory(2_048)

  private func memoryRow(
    _ source: DebugMemoryRow.Source = .unattributed,
    processCount: Int? = 2,
    selfMemory: UInt64? = 1_024,
    terminalRow: DebugTerminalRow? = nil,
  ) -> DebugMemoryRow {
    DebugMemoryRow(
      source: source,
      title: "Shell",
      subtitle: "acme / main",
      processCount: processCount,
      selfMemory: selfMemory,
      totalMemory: 2_048,
      barFraction: 1,
      terminalRow: terminalRow,
      appPartRows: [],
      processRows: [],
    )
  }

  private func processRow(depth: Int) -> DebugProcessRow {
    DebugProcessRow(
      process: .sample(pid: 10, footprint: 1_024),
      depth: depth,
      totalMemory: 2_048,
    )
  }

  @Test func theQuickStatsAreSpokenWithTheirUnits() {
    let stats = DebugQuickStats(
      history: .of([
        DebugSample.sample(sequence: 0, appCPUPercent: 30, childrenCPUPercent: 4)
      ])
    )
    let spoken = AccessibilityText.debugQuickStats(stats)

    #expect(spoken.hasPrefix("Debug Info, 34% CPU, "))
    #expect(spoken.contains(", \(stats.totalMemoryText) memory, "))
    #expect(spoken.hasSuffix(" of disk a second"))
  }

  @Test func theQuickStatsBeforeAnySampleAreSpokenAsTheirNameAlone() {
    #expect(
      AccessibilityText.debugQuickStats(DebugQuickStats(history: DebugHistory())) == "Debug Info"
    )
  }

  @Test func aMemoryRowIsSpokenWithItsCountsAndWhetherItIsOpen() {
    #expect(
      AccessibilityText.debugMemoryRow(memoryRow(), disclosure: .collapsed)
        == "Shell, acme / main, 2 processes, \(kilobyte) self, \(twoKilobytes) total, collapsed"
    )
    #expect(
      AccessibilityText.debugMemoryRow(memoryRow(), disclosure: .expanded)
        .hasSuffix(", expanded")
    )
  }

  @Test func aRowThatCannotOpenSaysNothingAboutOpening() {
    let spoken = AccessibilityText.debugMemoryRow(
      memoryRow(.total, processCount: nil, selfMemory: nil),
      disclosure: .notExpandable,
    )
    #expect(spoken == "Shell, acme / main, \(twoKilobytes) total")
  }

  @Test func aProcessIsSpokenWithItsDepthOnlyWhereSomethingStartedIt() {
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 0), under: memoryRow())
        == "p10, \(kilobyte) self, \(twoKilobytes) total"
    )
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 2), under: memoryRow())
        == "p10, started by the process above, 2 deep, \(kilobyte) self, \(twoKilobytes) total"
    )
  }

  @Test func aShellAtTheTopOfATabIsSpokenAsRunningInTheTerminalAboveIt() {
    let tabWithTerminal = memoryRow(
      terminalRow: DebugTerminalRow(selfMemory: 1_024, totalMemory: 2_048)
    )
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 0), under: tabWithTerminal)
        == "p10, runs in the terminal above, \(kilobyte) self, \(twoKilobytes) total"
    )
    #expect(
      AccessibilityText.debugProcessRow(processRow(depth: 2), under: tabWithTerminal)
        == "p10, started by the process above, 2 deep, \(kilobyte) self, \(twoKilobytes) total"
    )
  }

  @Test func aColumnHeaderSaysWhichWayTheTableIsSortedOnlyWhereItIsSortedByIt() {
    let sort = DebugCLIActivityColumn.defaultSort
    #expect(
      AccessibilityText.debugColumnHeader("Total", column: .totalDuration, sort: sort)
        == "Total, sorted descending"
    )
    #expect(
      AccessibilityText.debugColumnHeader(
        "Total",
        column: .totalDuration,
        sort: sort.selecting(.totalDuration),
      ) == "Total, sorted ascending"
    )
    #expect(AccessibilityText.debugColumnHeader("Runs", column: .runs, sort: sort) == "Runs")
  }

  @Test func aPartOfTheAppIsSpokenWithItsOwnShareAndWhatItHoldsWithTheRowsUnderIt() {
    #expect(
      AccessibilityText.debugAppPartRow(
        DebugAppPartRow(part: .heapInUse, selfMemory: 1_024, totalMemory: 2_048)
      ) == "Heap in use, \(kilobyte) self, \(twoKilobytes) total"
    )
  }

  @Test func anAppActivityRowIsSpokenWithItsTotalTime() {
    var tally = DebugWorkTally.empty
    tally.add(.milliseconds(1), bytesWritten: 100)
    tally.add(.milliseconds(3), bytesWritten: 200)
    let spoken = AccessibilityText.debugAppActivityRow(
      DebugAppActivityRow(kind: .stateSaves, tally: tally)
    )
    #expect(spoken.hasPrefix("State saves, 4 ms total, "))
  }

  @Test func aThreadGroupIsSpokenWithItsFiguresAndWhetherItIsOpen() {
    let row = DebugThreadGroupRow(
      group: .terminals,
      threads: [
        DebugThreadRow(
          key: DebugThreadKey(group: .terminals, name: "io"),
          tally: DebugThreadTally(threadCount: 2, cpuTime: .milliseconds(40)),
          meanPercent: 4,
        )
      ],
      threadCount: 2,
    )
    #expect(
      AccessibilityText.debugThreadRow(row, disclosure: .collapsed)
        == "Terminals, 2 threads, mean 4% CPU, 40 ms CPU time, collapsed"
    )
  }

  @Test func aPartDrawnUnderAnotherIsSpokenAsPartOfTheRowAbove() {
    #expect(
      AccessibilityText.debugAppPartRow(
        DebugAppPartRow(part: .fileTabs, selfMemory: 1_024, indentLevel: 1, fileTabCount: 2)
      )
        == "File tabs, 2 open, estimated, part of the row above, \(kilobyte) self, \(kilobyte) total"
    )
  }

  @Test func aTerminalIsSpokenWithWhatItHoldsAndWhatItsShellsHoldWithIt() {
    #expect(
      AccessibilityText.debugTerminalRow(DebugTerminalRow(selfMemory: 1_024, totalMemory: 2_048))
        == "Terminal, \(kilobyte) self, \(twoKilobytes) total"
    )
  }
}
