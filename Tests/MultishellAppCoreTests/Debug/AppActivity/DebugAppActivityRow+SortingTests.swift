import Testing

@testable import MultishellAppCore

@Suite
struct DebugAppActivityRowSortingTests {
  private var saves: DebugAppActivityRow {
    var tally = DebugWorkTally.empty
    tally.add(.milliseconds(1), bytesWritten: 100)
    tally.add(.milliseconds(3), bytesWritten: 200)
    return DebugAppActivityRow(kind: .stateSaves, tally: tally)
  }

  @Test func eachColumnSortsByItsOwnFigure() {
    #expect(saves.sortKey(by: .activity) == .text("State saves"))
    #expect(saves.sortKey(by: .count) == .number(2))
    #expect(saves.sortKey(by: .totalDuration) == .number(0.004))
    #expect(saves.sortKey(by: .meanDuration) == .number(0.002))
    #expect(saves.sortKey(by: .slowestDuration) == .number(0.003))
    #expect(saves.sortKey(by: .bytesWritten) == .number(300))
  }

  @Test func reportsWriteNothingSoHaveNoReadingUnderWritten() {
    var tally = DebugWorkTally.empty
    tally.add(.milliseconds(1))
    let reports = DebugAppActivityRow(kind: .stateReports, tally: tally)
    #expect(reports.sortKey(by: .bytesWritten) == nil)
  }
}
