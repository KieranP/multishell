import MultishellProcess

extension DebugAppActivityRow: DebugSortableRow {
  var sortName: String { title }

  func sortKey(by column: DebugAppActivityColumn) -> DebugSortKey? {
    switch column {
    case .bytesWritten: bytesWritten.map { .number(Double($0)) }
    case .count: .number(Double(tally.count))
    case .meanDuration: .number(tally.meanDuration.inSeconds)
    case .slowestDuration: .number(tally.slowestDuration.inSeconds)
    case .totalDuration: .number(tally.totalDuration.inSeconds)
    case .activity: .text(title)
    }
  }
}
