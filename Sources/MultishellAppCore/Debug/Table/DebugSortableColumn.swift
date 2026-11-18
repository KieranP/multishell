/// A debug table's column, which its header sorts the rows by.
public protocol DebugSortableColumn: Sendable, Hashable {
  /// The order the table opens in.
  static var defaultSort: DebugTableSort<Self> { get }
  /// Text reads A to Z first, a figure largest first: the end worth reading.
  var sortsAscendingFirst: Bool { get }
  /// What the table's caption says it is sorted by.
  var sortTitle: String { get }
}
