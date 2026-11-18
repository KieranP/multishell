/// A column of Memory Breakdown, which its header sorts the rows by.
public enum DebugMemoryColumn: DebugSortableColumn {
  case name
  case processCount
  case selfMemory
  case totalMemory
  case worktree

  public static let defaultSort = DebugTableSort(column: Self.totalMemory, isAscending: false)

  public var sortsAscendingFirst: Bool { self == .name || self == .worktree }
}
