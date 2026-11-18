import Foundation

/// Which column a debug table is sorted by, and which way.
public struct DebugTableSort<Column: DebugSortableColumn>: Sendable, Equatable {
  public let column: Column
  public let isAscending: Bool

  /// What the table's caption says it is sorted by.
  public var title: String { column.sortTitle }

  /// A second click on the sorted column turns it round; another column
  /// starts at its own first direction.
  public func selecting(_ column: Column) -> Self {
    guard column == self.column else {
      return Self(column: column, isAscending: column.sortsAscendingFirst)
    }
    return Self(column: column, isAscending: !isAscending)
  }

  /// A row with no reading goes last either way; ties go by name, so a
  /// redraw keeps the order.
  func ordered<Row: DebugSortableRow>(_ rows: [Row]) -> [Row] where Row.Column == Column {
    rows.sorted { lhs, rhs in
      switch (lhs.sortKey(by: column), rhs.sortKey(by: column)) {
      case (nil, nil): return lhs.sortName < rhs.sortName

      case (nil, _): return false

      case (_, nil): return true

      case (let left?, let right?):
        switch left.compare(right) {
        case .orderedSame: return lhs.sortName < rhs.sortName

        case .orderedAscending: return isAscending

        case .orderedDescending: return !isAscending
        }
      }
    }
  }
}
