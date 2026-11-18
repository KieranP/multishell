import MultishellAppCore
import MultishellCore
import SwiftUI

/// A debug table's column title that sorts the table by its column, with an
/// arrow beside it while the table is sorted by it.
struct DebugColumnHeaderButton<Column: DebugSortableColumn>: View {
  let title: String
  let column: Column
  @Binding var sort: DebugTableSort<Column>
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let isSorted = sort.column == column
    Button {
      sort = sort.selecting(column)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(title)
        if isSorted {
          Image(systemName: sort.isAscending ? "chevron.up" : "chevron.down")
            .font(metrics.font(size: metrics.debugTableGlyphSize, weight: .semibold))
        }
      }
      .foregroundStyle(isSorted ? theme.debugInfo.textSecondary : theme.debugInfo.textTertiary)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(AccessibilityText.debugColumnHeader(title, column: column, sort: sort))
  }
}
