import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelDebugAppActivityTests {
  @Test func reportsAndSavesAddUpOverTheRangeTheMostTimeFirst() throws {
    let harness = Harness()
    var reports = DebugWorkTally.empty
    reports.add(.milliseconds(1))
    var saves = DebugWorkTally.empty
    saves.add(.milliseconds(4), bytesWritten: 11_000)
    var first = DebugSample.sample(sequence: 0)
    first.stateSaves = saves
    var second = DebugSample(
      sequence: 1,
      takenAt: first.takenAt,
      elapsed: .seconds(1),
      frameRate: nil,
      cliExecutionsStartedCount: 0,
      cliExecutionsRunningCount: 0,
      cliExecutions: [:],
      appCPUPercent: 0,
      childrenCPUPercent: 0,
      appMemory: 0,
      terminalMemory: 0,
      childrenMemory: 0,
      stateReports: reports,
    )
    second.stateSaves = saves
    harness.model.debugHistory = .of([first, second])

    let rows = harness.model.debugAppActivityRows(
      for: .oneMinute,
      sortedBy: DebugAppActivityColumn.defaultSort,
    )

    #expect(rows.map(\.kind) == [.stateSaves, .stateReports])
    #expect(rows.map(\.countText) == ["2", "1"])
    #expect(rows.first?.bytesWrittenText == DebugValueText.memory(22_000))
    #expect(rows.last?.bytesWrittenText == "–", "a report writes nothing")
  }

  @Test func workThatNeverRanInTheRangeIsLeftOut() {
    let harness = Harness()
    harness.model.debugHistory = .of([.sample(sequence: 0)])
    #expect(
      harness.model.debugAppActivityRows(
        for: .oneMinute,
        sortedBy: DebugAppActivityColumn.defaultSort,
      )
      .isEmpty
    )
  }

  @Test func theRowsFollowTheSortAskedFor() {
    let harness = Harness()
    var reports = DebugWorkTally.empty
    for _ in 0..<3 { reports.add(.milliseconds(1)) }
    var saves = DebugWorkTally.empty
    saves.add(.milliseconds(9), bytesWritten: 10)
    var sample = DebugSample.sample(sequence: 0, stateReportCount: 3)
    sample.stateSaves = saves
    harness.model.debugHistory = .of([sample])

    let rows = harness.model.debugAppActivityRows(
      for: .oneMinute,
      sortedBy: DebugTableSort(column: .count, isAscending: false),
    )

    #expect(rows.map(\.title) == ["State reports handled", "State saves"])
  }
}
