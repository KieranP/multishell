import MultishellAppCore
import MultishellCore
import SwiftUI

/// Makes a debug table's sorting column titles, each bound to the table's sort.
@MainActor
struct DebugColumnHeaders<Column: DebugSortableColumn> {
  let sort: Binding<DebugTableSort<Column>>
  let theme: Theme
  let metrics: UIMetrics

  func button(_ title: String, _ column: Column) -> DebugColumnHeaderButton<Column> {
    DebugColumnHeaderButton(
      title: title,
      column: column,
      sort: sort,
      theme: theme,
      metrics: metrics,
    )
  }
}
