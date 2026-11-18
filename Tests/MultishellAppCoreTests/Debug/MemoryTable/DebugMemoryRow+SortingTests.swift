import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMemoryRowSortingTests {
  private var table: DebugMemoryTable {
    DebugMemoryTable(
      appMemory: 300,
      tabs: [
        tab("Shell", worktree: "main", footprint: 500),
        tab("Claude", worktree: "beta", footprint: 100),
      ],
      unattributedProcesses: [.sample(pid: 9, footprint: 50)],
    )
  }

  private func tab(_ title: String, worktree: String, footprint: UInt64) -> DebugTabMemory {
    DebugTabMemory(
      id: UUID(),
      title: title,
      location: DebugLocation(projectName: "acme", worktreeName: worktree),
      terminalMemory: nil,
      processes: [.sample(pid: Int32(footprint), footprint: footprint)],
    )
  }

  @Test func theTotalStaysLastWhicheverWayTheRowsAreSorted() {
    for isAscending in [true, false] {
      let rows = table.rows(
        sortedBy: DebugTableSort(column: .totalMemory, isAscending: isAscending)
      )
      #expect(rows.last?.isTotal == true)
    }
  }

  @Test func theRowsSortByTheirTotalByDefaultTheHeaviestFirst() {
    let titles = table.rows(sortedBy: DebugMemoryColumn.defaultSort).map(\.title)
    #expect(
      titles == [
        "Shell", "Multishell", "Claude", "Other processes", "Total, app and child processes",
      ]
    )
  }

  @Test func rowsWithNoWorktreeGoLastUnderTheWorktreeColumn() {
    let titles = table.rows(sortedBy: DebugTableSort(column: .worktree, isAscending: true)).map(
      \.title
    )
    #expect(Array(titles.prefix(2)) == ["Claude", "Shell"])
    #expect(Set(titles.dropFirst(2).dropLast()) == ["Multishell", "Other processes"])
  }

  @Test func eachColumnSortsByItsOwnFigure() throws {
    let terminalTab = DebugTabMemory(
      id: UUID(),
      title: "Shell",
      location: DebugLocation(projectName: "acme", worktreeName: "main"),
      terminalMemory: 40,
      processes: [.sample(pid: 1, footprint: 100), .sample(pid: 2, parentPID: 1, footprint: 60)],
    )
    let table = DebugMemoryTable(appMemory: 300, tabs: [terminalTab], unattributedProcesses: [])
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.sortKey(by: .name) == .text("Shell"))
    #expect(row.sortKey(by: .worktree) == .text("acme / main"))
    #expect(row.sortKey(by: .processCount) == .number(2))
    #expect(row.sortKey(by: .selfMemory) == .number(140))
    #expect(row.sortKey(by: .totalMemory) == .number(200))
  }
}
