/// A debug table row: its figure under each column, and the name ties fall back to.
protocol DebugSortableRow {
  associatedtype Column: DebugSortableColumn

  var sortName: String { get }

  /// `nil` where the row has no reading under the column.
  func sortKey(by column: Column) -> DebugSortKey?
}
