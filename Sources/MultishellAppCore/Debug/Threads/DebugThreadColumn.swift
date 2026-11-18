/// A column of CPU Breakdown, which its header sorts the rows by.
public enum DebugThreadColumn: DebugSortableColumn {
  case cpuTime
  case meanPercent
  case thread
  case threadCount

  public static let defaultSort = DebugTableSort(column: Self.cpuTime, isAscending: false)

  public var sortsAscendingFirst: Bool { self == .thread }
}
