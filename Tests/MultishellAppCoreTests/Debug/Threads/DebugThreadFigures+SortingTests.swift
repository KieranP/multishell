import Testing

@testable import MultishellAppCore

@Suite
struct DebugThreadFiguresSortingTests {
  @Test func eachColumnSortsByItsOwnFigure() {
    let row = DebugThreadRow(
      key: DebugThreadKey(group: .other, name: "io"),
      tally: DebugThreadTally(threadCount: 3, cpuTime: .milliseconds(250)),
      meanPercent: 7,
    )

    #expect(row.sortKey(by: .thread) == .text("io"))
    #expect(row.sortKey(by: .threadCount) == .number(3))
    #expect(row.sortKey(by: .cpuTime) == .number(0.25))
    #expect(row.sortKey(by: .meanPercent) == .number(7))
  }
}
