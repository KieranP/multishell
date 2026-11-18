import MultishellProcess

extension DebugThreadFigures {
  var sortName: String { title }

  func sortKey(by column: DebugThreadColumn) -> DebugSortKey? {
    switch column {
    case .cpuTime: .number(cpuTime.inSeconds)
    case .meanPercent: .number(meanPercent)
    case .thread: .text(title)
    case .threadCount: .number(Double(threadCount))
    }
  }
}
