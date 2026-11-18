/// A column of the CLI Activity table, which its header sorts the rows by.
public enum DebugCLIActivityColumn: DebugSortableColumn {
  case command
  case meanDuration
  case meanPeakMemory
  case peakMemory
  case runs
  case slowestDuration
  case slowestLocation
  case totalDuration

  public static let defaultSort = DebugTableSort(column: Self.totalDuration, isAscending: false)

  public var sortsAscendingFirst: Bool {
    switch self {
    case .command, .slowestLocation:
      true

    case .meanDuration, .meanPeakMemory, .peakMemory, .runs, .slowestDuration, .totalDuration:
      false
    }
  }
}
