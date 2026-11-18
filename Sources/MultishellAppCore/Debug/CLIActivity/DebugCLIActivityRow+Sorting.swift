import MultishellProcess

extension DebugCLIActivityRow: DebugSortableRow {
  var sortName: String { command }

  func sortKey(by column: DebugCLIActivityColumn) -> DebugSortKey? {
    switch column {
    case .command: .text(command)
    case .runs: .number(Double(tally.runCount))
    case .totalDuration: .number(tally.totalDuration.inSeconds)
    case .meanDuration: .number(tally.meanDuration.inSeconds)
    case .slowestDuration: .number(tally.slowestDuration.inSeconds)
    case .meanPeakMemory: tally.meanPeakMemory.map { .number(Double($0)) }
    case .peakMemory: tally.peakMemory.map { .number(Double($0)) }
    case .slowestLocation: slowestLocation.map { .text($0.title) }
    }
  }
}
