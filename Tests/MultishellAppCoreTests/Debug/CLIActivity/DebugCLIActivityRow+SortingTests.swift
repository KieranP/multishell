import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct DebugCLIActivityRowSortingTests {
  private func row(
    _ command: String,
    milliseconds: Int = 100,
    peakMemory: UInt64? = nil,
    location: DebugLocation? = nil,
  ) -> DebugCLIActivityRow {
    let run = GitRun.sample(command, milliseconds: milliseconds, peakMemory: peakMemory)
    return DebugCLIActivityRow(
      command: command,
      tally: CLIExecutionTally.byCommand([run])[command]!,
      slowestLocation: location,
    )
  }

  @Test func theTableStartsWithTheMostTimeSpentFirstTiesByCommand() {
    let rows = [
      row("diff", milliseconds: 100), row("status", milliseconds: 300),
      row("add", milliseconds: 100),
    ]
    #expect(
      DebugCLIActivityColumn.defaultSort.ordered(rows).map(\.command) == ["status", "add", "diff"]
    )
  }

  private func row(
    _ command: String,
    runs: [(milliseconds: Int, peakMemory: UInt64)],
  )
    -> DebugCLIActivityRow
  {
    let cliExecutions = runs.map { run in
      GitRun.sample(command, milliseconds: run.milliseconds, peakMemory: run.peakMemory)
    }
    return DebugCLIActivityRow(
      command: command,
      tally: CLIExecutionTally.byCommand(cliExecutions)[command]!,
      slowestLocation: nil,
    )
  }

  @Test func eachColumnOrdersByItsOwnFigure() {
    let rows = [
      row("status", runs: [(10, 100), (900, 500)]),
      row("log", runs: [(600, 400)]),
      row("diff", runs: [(250, 350), (250, 350), (250, 350)]),
      row("add", runs: [(700, 380), (200, 50), (200, 50), (200, 50)]),
    ]
    let order = { (column: DebugCLIActivityColumn) in
      DebugTableSort(column: column, isAscending: false).ordered(rows).map(\.command)
    }

    #expect(order(.runs) == ["add", "diff", "status", "log"])
    #expect(order(.totalDuration) == ["add", "status", "diff", "log"])
    #expect(order(.meanDuration) == ["log", "status", "add", "diff"])
    #expect(order(.slowestDuration) == ["status", "add", "log", "diff"])
    #expect(order(.meanPeakMemory) == ["log", "diff", "status", "add"])
    #expect(order(.peakMemory) == ["status", "log", "add", "diff"])
    #expect(order(.command) == ["status", "log", "diff", "add"])
    #expect(
      DebugTableSort(column: .command, isAscending: true).ordered(rows).map(\.command)
        == ["add", "diff", "log", "status"]
    )
  }

  @Test func aRowWithNoReadingGoesLastWhicheverWayTheColumnRuns() {
    let rows = [
      row("status", peakMemory: nil, location: nil),
      row(
        "log",
        peakMemory: 300,
        location: DebugLocation(projectName: "acme", worktreeName: "b"),
      ),
      row(
        "diff",
        peakMemory: 200,
        location: DebugLocation(projectName: "acme", worktreeName: "a"),
      ),
    ]
    for isAscending in [true, false] {
      for column in [DebugCLIActivityColumn.peakMemory, .meanPeakMemory, .slowestLocation] {
        let order = DebugTableSort(column: column, isAscending: isAscending).ordered(rows)
        #expect(order.last?.command == "status", "\(column) ascending \(isAscending)")
      }
    }
  }
}
