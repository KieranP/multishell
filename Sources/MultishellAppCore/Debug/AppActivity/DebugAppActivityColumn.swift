/// A column of App Activity, which its header sorts the rows by.
public enum DebugAppActivityColumn: DebugSortableColumn {
  case activity
  case bytesWritten
  case count
  case meanDuration
  case slowestDuration
  case totalDuration

  public static let defaultSort = DebugTableSort(column: Self.totalDuration, isAscending: false)

  public var sortsAscendingFirst: Bool { self == .activity }
}
